//
//  E2edit.m
//  iPack
//
//  Created by 松山 和正 on 09/12/04.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//
// InterfaceBuilderを使わずに作ったViewController

#import "Global.h"
#import "AppDelegate.h"
#import "Elements.h"
#import "E2viewController.h"
#import "E2edit.h"


@interface E2edit (PrivateMethods)
- (void)cancel:(id)sender;
- (void)save:(id)sender;
- (void)viewDesign;
- (void)tvNoteNarrow; // Noteフィールドをキーボードに隠れなくする
@end

@implementation E2edit   // ViewController
{
@private
	//E1 *Re1selected;  // Edit時は IaE2target.parent と同値であるが、Add時にはこれを頼りにする必要がある。 
	//E2 *Re2target;
	//NSInteger PiAddRow;  // (>=0)Add  (-1)Edit
	//BOOL	PbSharePlanList;	// SharePlan プレビューモード
	
	// E2viewが左ペインにあるとき、E2editをPopover内包するために使う。
	//id									delegate;
	//UIPopoverController*	selfPopover;  // 自身を包むPopover  閉じる為に必要
	
	//----------------------------------------------viewDidLoadでnil, dealloc時にrelese
	//----------------------------------------------Owner移管につきdealloc時のrelese不要
	UITextField *MtfName;
	UITextView	*MtvNote;
	//----------------------------------------------assign
	AppDelegate		*appDelegate_;
}
@synthesize Re1selected;
@synthesize Re2target;
@synthesize PiAddRow;
@synthesize PbSharePlanList;
@synthesize delegate;
@synthesize selfPopover;

- (void)dealloc 
{
	//[selfPopover release], 
	selfPopover = nil;
	// @property (retain)
	//[Re2target release];
	//[Re1selected release];
	//[super dealloc];
}

- (id)init 
{
	self = [super init];
	if (self) {
		// 初期化処理：インスタンス生成時に1回だけ通る
		appDelegate_ = (AppDelegate *)[[UIApplication sharedApplication] delegate];
		appDelegate_.AppUpdateSave = NO;
		PbSharePlanList = NO;

		if (appDelegate_.app_is_iPad) {
			self.contentSizeForViewInPopover = GD_POPOVER_SIZE;
		}
	}
	return self;
}

// IBを使わずにviewオブジェクトをプログラム上でcreateするときに使う
//（viewDidLoadは、nibファイルでロードされたオブジェクトを初期化するために使う）
- (void)loadView
{	//【Tips】ここでaddSubviewするオブジェクトは全てautoreleaseにすること。メモリ不足時には自動的に解放後、改めてここを通るので、初回同様に生成するだけ。
	[super loadView];

	self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];

	// E2.name
	MtfName = [[UITextField alloc] init];

	if (appDelegate_.app_is_iPad) {
		MtfName.font = [UIFont systemFontOfSize:20];
	} else {
		MtfName.font = [UIFont systemFontOfSize:16];
	}
	MtfName.textColor = [UIColor blackColor];
	MtfName.borderStyle = UITextBorderStyleRoundedRect;
	MtfName.placeholder = NSLocalizedString(@"(New Index)",nil);  //(@"Group name", @"グループ名称");
	MtfName.keyboardType = UIKeyboardTypeDefault;
	MtfName.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter; // 縦中央
	MtfName.delegate = self;
	[self.view addSubview:MtfName]; //[MtfName release]; // self.viewがOwnerになる
	// E2.note
	MtvNote = [[UITextView alloc] init];

	if (appDelegate_.app_is_iPad) {
		MtvNote.font = [UIFont systemFontOfSize:20];
	} else {
		MtvNote.font = [UIFont systemFontOfSize:14];
	}
	MtvNote.textColor = [UIColor brownColor];
	MtvNote.keyboardType = UIKeyboardTypeDefault;
	MtvNote.delegate = self;  // textViewDidBeginEditingなどが呼び出されるように
	[self.view addSubview:MtvNote]; //[MtvNote release]; // self.viewがOwnerになる
	
	// CANCELボタンを左側に追加する  Navi標準の戻るボタンでは cancel:処理ができないため
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
											  initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
											  target:self action:@selector(cancel:)];
	if (PbSharePlanList==NO) {
		// SAVEボタンを右側に追加する
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
												   initWithBarButtonSystemItem:UIBarButtonSystemItemSave
												   target:self action:@selector(save:)];
		self.navigationItem.rightBarButtonItem.enabled = NO; // 変更なし [Save]無効
	}
}

- (void)viewDidLoad 
{
	[super viewDidLoad];
	// 背景テクスチャ・タイルペイント
	self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"Tx-Back"]];

	// listen to our app delegates notification that we might want to refresh our detail view
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshAllViews:) name:NFM_REFRESH_ALL_VIEWS
											   object:[[UIApplication sharedApplication] delegate]];
}

- (void)viewDidUnload 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];
	
	// 画面表示に関係する Option Setting を取得する
	//NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	[self viewDesign];
	
	if ([[Re2target valueForKey:@"name"] isEqualToString:NSLocalizedString(@"New Index",nil)]) {
		MtfName.text = @"";
	} else {
		MtfName.text = [Re2target valueForKey:@"name"];
	}

	MtvNote.text = [Re2target valueForKey:@"note"];

}

// 画面表示された直後に呼び出される
- (void)viewDidAppear:(BOOL)animated 
{
	[super viewDidAppear:animated];
	//viewWillAppearでキーを表示すると画面表示が無いまま待たされてしまうので、viewDidAppearでキー表示するように改良した。
	if ([MtfName.text length]<=0) {			// ブランクならば、
		[MtfName becomeFirstResponder];  // キーボード表示
	}
}

// ビューが非表示にされる前や解放される前ににこの処理が呼ばれる
- (void)viewWillDisappear:(BOOL)animated 
{
	[super viewWillDisappear:animated];
	// 戻る前にキーボードを消さないと、次に最初から現れた状態になり、表示されるまでが遅くなってしまう。
	// キーボードを消すために全てのコントロールへresignFirstResponderを送る ＜表示中にしか効かない＞
	[MtfName resignFirstResponder];
	[MtvNote resignFirstResponder];
}

// 回転サポート
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{	
	if (appDelegate_.app_is_iPad) {
		return NO;	//[MENU]Popover内のとき回転禁止にするため
	} else {
		// 回転禁止でも万一ヨコからはじまった場合、タテにはなるようにしてある。
		return appDelegate_.AppShouldAutorotate OR (interfaceOrientation == UIInterfaceOrientationPortrait);
	}
}

// ユーザインタフェースの回転の最後の半分が始まる前にこの処理が呼ばれる　＜＜このタイミングで配置転換すると見栄え良い＞＞
- (void)willAnimateSecondHalfOfRotationFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation 
													   duration:(NSTimeInterval)duration
{
	if (appDelegate_.app_is_iPad) {
		[self cancel:nil];	//回転すればキャンセル
	} else {
		//[self viewWillAppear:NO];没：これを呼ぶと、回転の都度、編集がキャンセルされてしまう。
		[self viewDesign]; // これで回転しても編集が継続されるようになった。
	}
}

- (void)viewDesign
{
	if (appDelegate_.app_is_iPad) {
		CGRect rect;
		rect.origin.x = 10;
		rect.origin.y = 5;
		rect.size.width = self.view.frame.size.width - rect.origin.x * 2;
		rect.size.height = 40;
		MtfName.frame = rect;
		
		rect.origin.x = 15;
		rect.origin.y = 48;
		rect.size.width = self.view.frame.size.width - rect.origin.x * 2;
		rect.size.height = self.view.frame.size.height - rect.origin.y - 10;
		MtvNote.frame = rect;
	}
	else {
		float fKeyHeight;
		float fHeightOfsset;
		if (self.interfaceOrientation == UIInterfaceOrientationPortrait 
			OR self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
			fKeyHeight = GD_KeyboardHeightPortrait;	 // タテ
			fHeightOfsset = 15; // タテ： MtfNameの高さを少しでも高くして操作しやすくする
		} else {
			fKeyHeight = GD_KeyboardHeightLandscape; // ヨコ
			fHeightOfsset = 0; // ヨコ： MtvNoteの高さをできるだけ確保しなければ入力しにくくなる
		}
		
		CGRect rect;
		rect.origin.x = 10;
		rect.origin.y = 5;
		rect.size.width = self.view.frame.size.width - rect.origin.x * 2;
		rect.size.height = 25 + fHeightOfsset;
		MtfName.frame = rect;
		
		rect.origin.x = 15;
		rect.origin.y = 33 + fHeightOfsset;
		rect.size.width = self.view.frame.size.width - rect.origin.x * 2;
		rect.size.height = self.view.frame.size.height - rect.origin.y - 5 - fKeyHeight;
		MtvNote.frame = rect;
	}
}


#pragma mark - iCloud
- (void)refreshAllViews:(NSNotification*)note 
{	// iCloud-CoreData に変更があれば呼び出される
    //if (note) {
		//[self.tableView reloadData];
		[self viewWillAppear:YES];
    //}
}


#pragma mark - <UITextFieldDelegate>
// <UITextFieldDelegate> テキストが変更される「直前」に呼び出される。これにより入力文字数制限を行っている。
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range 
replacementString:(NSString *)string 
{
	// senderは、MtfName だけ
    NSMutableString *text = [textField.text mutableCopy];
    [text replaceCharactersInRange:range withString:string];
	// 置き換えた後の長さをチェックする
	if ([text length] <= AzMAX_NAME_LENGTH) {
		appDelegate_.AppUpdateSave = YES; // 変更あり
		self.navigationItem.rightBarButtonItem.enabled = YES; // 変更あり [Save]有効
		return YES;
	} else {
		return NO;
	}
}

// UITextView テキストが変更される「直前」に呼び出される。これにより入力文字数制限を行っている。
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range 
										replacementText:(NSString *)zReplace
{
	// senderは、MtvNote だけ
    NSMutableString *zText = [textView.text mutableCopy];
    [zText replaceCharactersInRange:range withString:zReplace];
	// 置き換えた後の長さをチェックする
	if ([zText length] <= AzMAX_NOTE_LENGTH) {
		appDelegate_.AppUpdateSave = YES; // 変更あり
		self.navigationItem.rightBarButtonItem.enabled = YES; // 変更あり [Save]有効
		return YES;
	} else {
		return NO;
	}
}


- (void)cancel:(id)sender 
{
	if (appDelegate_.app_is_iPad) {
		if (selfPopover) 
		{	//ヨコ： E2viewが左ペインにあるとき、E2editを内包するPopoverを閉じる
			[selfPopover dismissPopoverAnimated:YES];
			return;
		}
		//タテ： E2viewが[MENU]でPopover内包されているとき、E2editはiPhone同様にNavi遷移するだけ
	}
	[self.navigationController popViewControllerAnimated:YES];	// < 前のViewへ戻る
}

- (void)save:(id)sender 
{
	// 編集フィールドの値を editObj にセットする
	[Re2target setValue:MtfName.text forKey:@"name"];
	[Re2target setValue:MtvNote.text forKey:@"note"];
	
	if (0 <= PiAddRow) {
		// 新規のとき、末尾になるように行番号を付与する
		[Re2target setValue:[NSNumber numberWithInteger:PiAddRow] forKey:@"row"];
		// E2レベルでは新オブジェクトを上位のE1と関連させる
		[Re1selected addChildsObject:Re2target];
	}

	if (PbSharePlanList==NO) {  // SpMode=YESならば[SAVE]ボタンを非表示にしたので通らないハズだが、念のため。
		NSError *err = nil;
		if (![Re2target.managedObjectContext save:&err]) {
			NSLog(@"Unresolved error %@, %@", err, [err userInfo]);
			//abort();
		}
	}

	if (appDelegate_.app_is_iPad) {
		if (selfPopover) 
		{	//ヨコ： E2viewが左ペインにあるとき、E2editを内包するPopoverを閉じる
			if ([delegate respondsToSelector:@selector(refreshE2view)]) {	// メソッドの存在を確認する
				[delegate refreshE2view];// 親の再描画を呼び出す
			}
			[selfPopover dismissPopoverAnimated:YES];
			return;
		}
		//タテ： E2viewが[MENU]でPopover内包されているとき、E2editはiPhone同様にNavi遷移するだけ
	}
	[self.navigationController popViewControllerAnimated:YES];	// < 前のViewへ戻る
}


@end
