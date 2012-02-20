//
//  GDocUploadVC.m
//  AzPackList5
//
//  Created by Sum Positive on 12/02/18.
//  Copyright (c) 2012 Azukid. All rights reserved.
//

#import "Global.h"
#import "AppDelegate.h"
#import "SFHFKeychainUtils.h"
#import "Elements.h"
#import "EntityRelation.h"
#import "FileCsv.h"

#import "GoogleService.h"
#import "GDocUploadVC.h"

#define TAG_ACTION_UPLOAD					800
#define TAG_ACTION_UPLOAD_START	810


@implementation GDocUploadVC
{	// @Private
	AppDelegate						*mAppDelegate;
	UIAlertView							*mAlert;
	UIActivityIndicatorView		*mActivityIndicator;

	GDataServiceGoogleDocs	*mDocService;
	GDataFeedBase					*mDocFeed;
	GDataEntryDocBase			*mDocSelect;
}
@synthesize Re1selected;

/*
#pragma mark - Alert Indicator

- (void)alertIndicatorOn:(NSString*)zTitle
{
	[mAlert setTitle:zTitle];
	[mAlert show];
	[mActivityIndicator setFrame:CGRectMake((mAlert.bounds.size.width-50)/2, mAlert.frame.size.height-75, 50, 50)];
	[mActivityIndicator startAnimating];
}

- (void)alertIndicatorOff
{
	[mActivityIndicator stopAnimating];
	[mAlert dismissWithClickedButtonIndex:mAlert.cancelButtonIndex animated:YES];
}
*/

#pragma mark - IBAction

- (IBAction)ibBuUpload:(UIButton *)button
{
	NSString *filename = [ibTfName.text stringByDeletingPathExtension]; // 拡張子があれば除く
	if ([filename length] < 3) {
		alertBox(NSLocalizedString(@"Dropbox NameLeast", nil), NSLocalizedString(@"Dropbox NameLeastMsg", nil), @"OK");
		return;
	}
	
	UIActionSheet *as = [[UIActionSheet alloc] initWithTitle: filename
													delegate:self 
										   cancelButtonTitle: NSLocalizedString(@"Cancel", nil) 
									  destructiveButtonTitle: nil
										   otherButtonTitles: NSLocalizedString(@"Google Start upload", nil), nil];
	as.tag = TAG_ACTION_UPLOAD;
	[as showInView:self.view];
	[ibTfName resignFirstResponder]; // キーボードを隠す
}

- (IBAction)ibSwEncrypt:(UISwitch *)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:ibSwEncrypt.isOn forKey:UD_Crypt_Switch];
}

#pragma mark  <UIActionSheetDelegate>
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == actionSheet.cancelButtonIndex) return; // CANCEL
	if (actionSheet.tag != TAG_ACTION_UPLOAD) return;
	
	// アップロード開始
	[GoogleService docUploadE1:Re1selected  title:ibTfName.text  crypt:ibSwEncrypt.isOn];
}


#pragma mark - View lifecycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
		mAppDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
		if (mAppDelegate.app_is_iPad) {
			self.contentSizeForViewInPopover = CGSizeMake(480, 250); //GD_POPOVER_SIZE;
		}
		mDocService = [GoogleService docService];
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	
	self.title = Re1selected.name;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:UD_OptCrypt]) {
		ibLbEncrypt.enabled = YES;
		ibSwEncrypt.enabled = YES;
		[ibSwEncrypt setOn:[defaults boolForKey:UD_Crypt_Switch]];
	}
	
	ibTfName.keyboardType = UIKeyboardTypeDefault;
	ibTfName.returnKeyType = UIReturnKeyDone;
	ibTfName.text = Re1selected.name;
	
/*	mAlert = [[UIAlertView alloc] initWithTitle:@"" message:@"" delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
	mActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	mActivityIndicator.frame = CGRectMake(0, 0, 50, 50);
	[mAlert addSubview:mActivityIndicator];*/
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{	// Return YES for supported orientations
	if (mAppDelegate.app_opt_Autorotate==NO && mAppDelegate.app_is_iPad==NO) {	// 回転禁止にしている場合
		return (interfaceOrientation == UIInterfaceOrientationPortrait); // 正面（ホームボタンが画面の下側にある状態）のみ許可
	}
    return YES;
}



@end
