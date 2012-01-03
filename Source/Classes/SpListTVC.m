//
//  SpListTVC.m
//  AzPacking
//
//  Created by 松山 和正 on 10/01/27.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "Global.h"
#import "AppDelegate.h"
#import "Elements.h"
#import "FileCsv.h"
#import "SpPOST.h"
#import "SpListTVC.h"
#import "SpDetailTVC.h"
#import  <YAJLiOS/YAJL.h>

#define CELL_TAG_NAME		91
#define CELL_TAG_NOTE		92
#define CELL_TAG_INFO		93

#define ACTION_TAG_A_PLAN	901

#define ALERT_TAG_PREVIEW	802
#define ALERT_TAG_BREAK		811


#ifdef AzDEBUG
#define PAGE_LIMIT			3
#else
#define PAGE_LIMIT			20
#endif

@interface SpListTVC (PrivateMethods)
- (NSString *)vSharePlanSearch:(NSInteger)iOffset;
@end

@implementation SpListTVC
@synthesize	RaTags, RzSort;


- (void)unloadRelease	// dealloc, viewDidUnload から呼び出される
{
	NSLog(@"--- unloadRelease --- SpListTVC");

	[RurlConnection cancel]; // 停止させてから解放する
	[RurlConnection release],	RurlConnection = nil;

	[RdaResponse release],		RdaResponse = nil;
}

- (void)dealloc 
{
	[self unloadRelease];
	[RaSharePlans release],		RaSharePlans = nil;
	//--------------------------------@property (retain)
	[RaTags release];
	[RzSort release];
    [super dealloc];
}

- (void)viewDidUnload 
{	// メモリ不足時、裏側にある場合に呼び出されるので、viewDidLoadで生成したObjを解放する。
	//NSLog(@"--- viewDidUnload ---"); 
	// メモリ不足時、裏側にある場合に呼び出される。addSubviewされたOBJは、self.viewと同時に解放される
	[self unloadRelease];
	[super viewDidUnload];
	// この後に loadView ⇒ viewDidLoad ⇒ viewWillAppear がコールされる
}


- (id)initWithStyle:(UITableViewStyle)style 
{
	self = [super initWithStyle:UITableViewStylePlain];
	if (self) {
		// 初期化成功
		//RautoPool = [[NSAutoreleasePool alloc] init];	// [0.6]autorelease独自解放のため
		MbSearching = YES;
		RaSharePlans = [NSMutableArray new]; // unloadReleaseしないこと
#ifdef AzPAD
		self.contentSizeForViewInPopover = GD_POPOVER_SIZE;
#endif
	}
	return self;
}

// IBを使わずにviewオブジェクトをプログラム上でcreateするときに使う（viewDidLoadは、nibファイルでロードされたオブジェクトを初期化するために使う）
- (void)loadView
{
	[super loadView];

	self.tableView.allowsSelectionDuringEditing = YES;

	self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc]
											  initWithTitle:NSLocalizedString(@"Back", nil)
											  style:UIBarButtonItemStylePlain 
											  target:nil  action:nil] autorelease];
}

/*
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/

- (NSString *)vSharePlanSearch:(NSInteger)iOffset
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES; // NetworkアクセスサインON
	
	// POST URL
	NSString *postCmd = @"func=Search";
	//NSString *postCmd = [NSString stringWithString:@"func=Search"];
	
	// userPass
	postCmd = postCmdAddUserPass( postCmd );
	
	// language
	postCmd = postCmdAddLanguage( postCmd );
	
	// Search paramaters
	for (NSString *zz in self.RaTags) {
		postCmd = [postCmd stringByAppendingFormat:@"&tag=%@", zz];
	}
	postCmd = [postCmd stringByAppendingFormat:@"&sort=%@", self.RzSort];
	postCmd = [postCmd stringByAppendingFormat:@"&shLimit=%d", PAGE_LIMIT];
	postCmd = [postCmd stringByAppendingFormat:@"&shOffset=%ld", (long)iOffset];

	if (RurlConnection) {
		[RurlConnection cancel];
		[RurlConnection release], RurlConnection = nil;
	}
	// 非同期通信
	RurlConnection = [[NSURLConnection alloc] initWithRequest:requestSpPOST(postCmd)
													 delegate:self];
	MiConnectTag = 1; // Search
	return nil; //OK
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{	// データ受信時
	if (RdaResponse==nil) {
		RdaResponse = [NSMutableData new];
	}
	[RdaResponse appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{	// 通信終了時
	if (RdaResponse) {
		NSString *jsonStr = [[NSString alloc] initWithData:RdaResponse encoding:NSUTF8StringEncoding];
		AzLOG(@"jsonStr: %@", jsonStr);
		[RdaResponse setData:nil]; // 次回の受信に備えてクリアする
		 
		switch (MiConnectTag) {
			case 1: { // Search
				NSArray *jsonArray;
				@try {
					jsonArray = [jsonStr yajl_JSON]; // YAJLを使ったJSONデータのパース処理 
				}
				@catch (NSException *ex) {
					// jsonStrがJSON文字列ではない
					alertMsgBox( NSLocalizedString(@"Connection Error",nil), 
								nil,
								NSLocalizedString(@"Roger",nil) );
					[self.navigationController popViewControllerAnimated:YES];	// 前のViewへ戻る
					break;
				}
#ifdef AzDEBUG
				for (NSDictionary *dic in jsonArray) {
					NSLog(@"e1key=%@", [dic objectForKey:@"e1key"]);
					NSLog(@"name=%@", [dic objectForKey:@"name"]);
					NSLog(@"stamp=%@", [dic objectForKey:@"stamp"]);
					NSLog(@"downCount=%@", [dic objectForKey:@"downCount"]);
				}	
#endif
				[RaSharePlans addObjectsFromArray:jsonArray];
				MbSearchOver = ([jsonArray count] < PAGE_LIMIT);
				[self.tableView reloadData];
			}	break;
				
			default:
				break;
		}
		[jsonStr release];
	}
	else {
		// 該当なし
		[self.tableView reloadData];
	}
	MiConnectTag = 0; // 通信してません
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO; // NetworkアクセスサインOFF
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{	// 通信中断時
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO; // NetworkアクセスサインOFF
	MiConnectTag = 0; // 通信してません
	
	NSString *error_str = [error localizedDescription];
	if (0<[error_str length]) {
		alertMsgBox( NSLocalizedString(@"Connection Error",nil), 
					error_str,
					NSLocalizedString(@"Roger",nil) );
	}
	[RdaResponse release], RdaResponse = nil;
}


// 回転サポート
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{	
#ifdef AzPAD
	return NO;
#else
	// 回転禁止でも万一ヨコからはじまった場合、タテ（ボタン下部）にはなるようにしてある。
	AppDelegate *app = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	return app.AppShouldAutorotate OR (interfaceOrientation == UIInterfaceOrientationPortrait);
#endif
}

// ユーザインタフェースの回転の最後の半分が始まる前にこの処理が呼ばれる　＜＜このタイミングで配置転換すると見栄え良い＞＞
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self.tableView reloadData]; // cell回転(再描画)させるために必要
}

// 表示前
- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
	// 画面表示に関係する Option Setting を取得する
	//NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	self.title = NSLocalizedString(@"SharePlan",nil);
	
	[self.tableView reloadData]; // 次Viewから戻ったときに再描画する　＜＜特に削除後が重要＞＞
}

// 表示後
- (void)viewDidAppear:(BOOL)animated 
{
    [super viewDidAppear:animated];
	
	MbSearching = NO;

	if ([RaSharePlans count]<=0) {	
		// 最初の25個取得
		NSAutoreleasePool *methodPool = [[NSAutoreleasePool alloc] init];	// return前に [pool release] 必須！
		[self vSharePlanSearch:0];
		[methodPool release];
	}
}

/*
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
}
*/

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [RaSharePlans count] + 1;
}

// TableView セクション名を応答
//- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section 

// セルの高さを指示する
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if ([RaSharePlans count] <= indexPath.row) return 44;

	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
		return 70; // タテ
	} else {
		return 55; //ヨコ
	}
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
    static NSString *zCellPlan = @"CellPlan";
    static NSString *zCellTerm = @"CellTerm";
    UILabel *lb;

	if ([RaSharePlans count] <= indexPath.row) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:zCellTerm];
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										   reuseIdentifier:zCellTerm] autorelease];
			cell.textLabel.font = [UIFont systemFontOfSize:16];
		}
		if ([RaSharePlans count] <= 0) {
			if (MbSearching) {
				cell.textLabel.text = NSLocalizedString(@"SpPOST",nil);
			} else {
				cell.textLabel.text = NSLocalizedString(@"No PLAN",nil);
			}
			cell.textLabel.textAlignment = UITextAlignmentCenter;
		} else if (MbSearchOver) {
			cell.textLabel.text = NSLocalizedString(@"Over",nil);
			cell.textLabel.textAlignment = UITextAlignmentCenter;
		} else {
			cell.textLabel.text = NSLocalizedString(@"More",nil);
			cell.textLabel.textAlignment = UITextAlignmentRight;
		} 
		return cell;
	}
	
	NSAssert(indexPath.row < [RaSharePlans count], nil);
	// Plans
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:zCellPlan];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									   reuseIdentifier:zCellPlan] autorelease];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; // >
		//
		lb = [[UILabel alloc] init];
		lb.font = [UIFont systemFontOfSize:16];
		lb.textAlignment = UITextAlignmentLeft;
		lb.textColor = [UIColor blackColor];
		//lb.backgroundColor = [UIColor lightGrayColor]; // DEBUG
		lb.tag = CELL_TAG_NAME;
		[cell.contentView addSubview:lb]; [lb release];
		//
		lb = [[UILabel alloc] init];
		lb.font = [UIFont systemFontOfSize:12];
		lb.textAlignment = UITextAlignmentLeft;
		lb.numberOfLines = 2;
		lb.textColor = [UIColor blackColor];
		//lb.backgroundColor = [UIColor lightGrayColor]; // DEBUG
		lb.tag = CELL_TAG_NOTE;
		[cell.contentView addSubview:lb]; [lb release];
		//
		lb = [[UILabel alloc] init];
		lb.font = [UIFont systemFontOfSize:12];
		lb.textAlignment = UITextAlignmentRight;
		lb.textColor = [UIColor blackColor];
		lb.backgroundColor = [UIColor lightGrayColor];
		lb.tag = CELL_TAG_INFO;
		[cell.contentView addSubview:lb]; [lb release];
	}
	//
	NSDictionary *dic = [RaSharePlans objectAtIndex:indexPath.row];
	//NSString *zOwn = @"";  ＜＜セキュリティ！この段階では表示しない＞＞
	//if ([[dic objectForKey:@"own"] boolValue]) zOwn = NSLocalizedString(@"Owner",nil);
	
	// @"stamp"(W3C-DTF:UTC) --> NSDate 
	NSDateFormatter *df = [[NSDateFormatter alloc] init];
	[df setTimeStyle:NSDateFormatterFullStyle];
	[df setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZ"];
	NSDate *utc = [df dateFromString:[dic objectForKey:@"stamp"]];
	NSLog(@"stamp=%@ --> utc=%@", [dic objectForKey:@"stamp"], utc);
	// utc --> string
	[df setLocale:[NSLocale currentLocale]];  // 現在のロケールをセット
	[df setDateFormat:@"YYYY-MM-dd hh:mm:ss"];
	NSString *zStamp = [df stringFromDate:utc];
	[df release];
	
	// Nickname
	NSString *zNickname = @"";
	if ([dic objectForKey:@"userName"] != [NSNull null]) {
		zNickname = [dic objectForKey:@"userName"];
	}
	//
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
		// タテ
		lb = (UILabel *)[cell.contentView viewWithTag:CELL_TAG_NAME];
		lb.frame = CGRectMake(10,4, cell.frame.size.width-20,18);
		//AzLOG(@"dic---name=%@", [dic objectForKey:@"name"]);
		if ([dic objectForKey:@"name"] == [NSNull null]) {
			lb.text = NSLocalizedString(@"Undecided",nil);
		} else {
			lb.text = [dic objectForKey:@"name"];
		}
		
		lb = (UILabel *)[cell.contentView viewWithTag:CELL_TAG_NOTE];
		lb.frame = CGRectMake(10,23, cell.frame.size.width-40,70-14-1-23);
		if ([dic objectForKey:@"note"] == [NSNull null]) {
			lb.text = @"";
		} else {
			lb.text = [dic objectForKey:@"note"];
		}
		
		lb = (UILabel *)[cell.contentView viewWithTag:CELL_TAG_INFO];
//	lb.frame = CGRectMake(0,70-14, cell.frame.size.width ,14);
		lb.frame = CGRectMake(0,70-14, self.view.frame.size.width,14);
	/*	lb.text = [NSString stringWithFormat:@"%@    %@ %@   %@ %@  ", zOwn,
				   NSLocalizedString(@"Release",nil), [dic objectForKey:@"stamp"], 
				   NSLocalizedString(@"Popular",nil), [dic objectForKey:@"downCount"]];　*/
		lb.text = [NSString stringWithFormat:@"%@   %@ %@  ", zNickname, NSLocalizedString(@"Release",nil), zStamp];
	}
	else {
		// ヨコ
		lb = (UILabel *)[cell.contentView viewWithTag:CELL_TAG_NAME];
		lb.frame = CGRectMake(10,2, cell.frame.size.width-20,18);
		if ([dic objectForKey:@"name"] == [NSNull null]) {
			lb.text = NSLocalizedString(@"Undecided",nil);
		} else {
			lb.text = [dic objectForKey:@"name"];
		}
		
		lb = (UILabel *)[cell.contentView viewWithTag:CELL_TAG_NOTE];
		lb.frame = CGRectMake(10,21, cell.frame.size.width-40,55-14-1-21);
		if ([dic objectForKey:@"note"] == [NSNull null]) {
			lb.text = @"";
		} else {
			lb.text = [dic objectForKey:@"note"];
		}
		
		lb = (UILabel *)[cell.contentView viewWithTag:CELL_TAG_INFO];
		//lb.frame = CGRectMake(0,55-14, cell.frame.size.width,14);
		lb.frame = CGRectMake(0,55-14, self.view.frame.size.width,14);
	/*	lb.text = [NSString stringWithFormat:@"%@    %@ %@   %@ %@  ", zOwn,
				   NSLocalizedString(@"Release",nil), [dic objectForKey:@"stamp"], 
				   NSLocalizedString(@"Popular",nil), [dic objectForKey:@"downCount"]];　*/
		lb.text = [NSString stringWithFormat:@"%@   %@ %@  ", zNickname, NSLocalizedString(@"Release",nil), zStamp];
	}
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];	// 選択状態を解除する

	if (indexPath.row < [RaSharePlans count]) {
		NSDictionary *dic = [RaSharePlans objectAtIndex:indexPath.row];
		NSLog(@"##### own=%@", [[dic objectForKey:@"own"] boolValue]?@"YES":@"NO");
		// SpDetailTVC
		SpDetailTVC *vc = [[SpDetailTVC alloc] init];
		vc.RzSharePlanKey = [dic objectForKey:@"e1key"];
		vc.PbOwner = [[dic objectForKey:@"own"] boolValue];
		[self.navigationController pushViewController:vc animated:YES];
		[vc release];
	}
	else if (!MbSearchOver) {
		// Next Search
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		NSString *err = [self vSharePlanSearch:[RaSharePlans count]];
		if (err) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Search Err",nil)
															message:err
														   delegate:nil 
												  cancelButtonTitle:nil 
												  otherButtonTitles:NSLocalizedString(@"Roger",nil), nil];
			[alert show];
			[alert release];
		}
		[pool release];
	}
}	

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	switch (alertView.tag) {
		case ALERT_TAG_PREVIEW:	// 前画面に戻す
			[self.navigationController popViewControllerAnimated:YES];	// 前のViewへ戻る
			break;
			
		case ALERT_TAG_BREAK: // 通信中断する
			if (RurlConnection) {
				[RurlConnection cancel];
				[RurlConnection release], RurlConnection = nil;
			}
			[self.navigationController popViewControllerAnimated:YES];	// 前のViewへ戻る
			break;
	}
}


@end

