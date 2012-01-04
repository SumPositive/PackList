//
//  E3detailTVC.m
//  AzPacking
//
//  Created by 松山 和正 on 10/01/29.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "Global.h"
#import "AppDelegate.h"
#import "Elements.h"
#import "E3viewController.h"
#import "E3detailTVC.h"
#import "selectGroupTVC.h"
#import "editLabelTextVC.h"
#import "editLabelNumberVC.h"
#import "CalcView.h"
#import "WebSiteVC.h"


//#define LABEL_NOTE_SUFFIX   @"\n\n\n\n\n"  // UILabel *MlbNoteを上寄せするための改行（5行）
#define TEXTFIELD_MAXLENGTH		50
#define TEXTVIEW_MAXLENGTH		400
#define WEIGHT_SLIDER_STEP		   10		// Weight Slider Step (g)
#define WEIGHT_CENTER_OFFSET	  500		// Weight 中央値から最大最小値までの量
#define WEIGHT_MAX				99999		// Weight 中央値から最大最小値までの量
#define NEED_MAX				 9999
#define STOCK_MAX				 9999

#define OFSX1		115
#define OFSX2		 30


@interface E3detailTVC (PrivateMethods)
- (void)slidStock:(UISlider *)slider;
- (void)slidStockUp:(UISlider *)slider;
- (void)slidNeed:(UISlider *)slider;
- (void)slidNeedUp:(UISlider *)slider;
- (void)slidWeight:(UISlider *)slider;
- (void)slidWeightUp:(UISlider *)slider;
- (void)cellButtonCalc: (UIButton *)button ;
- (void)cancelClose:(id)sender;
- (void)saveClose:(id)sender;
- (void)viewDesign;
- (void)alertWeightOver;
@end

@implementation E3detailTVC
{
@private
	NSMutableArray	*RaE2array;
	NSMutableArray	*RaE3array;
	E3						*Re3target;
	NSInteger			PiAddGroup;		// =(-1)Edit  >=(E2.row)Add Mode
	NSInteger			PiAddRow;		//(V0.4)Add行の.row ここに追加する
	BOOL					PbSharePlanList;  // PbSpMode;	// SharePlan プレビューモード
	
	id									delegate;
	UIPopoverController*	selfPopover;  // 自身を包むPopover  閉じる為に必要
	
	//----------------------------------------------viewDidLoadでnil, dealloc時にrelese
	//NSAutoreleasePool	*MautoreleasePool;	autoreleaseオブジェクトを「戻り値」にしているため、ここでの破棄禁止
	//----------------------------------------------Owner移管につきdealloc時のrelese不要
	UILabel		*MlbGroup;	// .tag = E2.row　　　以下全てcellがOwnerになる
	UITextField	*MtfName;
	UITextField	*MtfKeyword;	//[1.1]Shopping keyword
	UITextView	*MtvNote;
	//UILabel		*MlbNote;
	UILabel		*MlbStock;
	UILabel		*MlbNeed;
	UILabel		*MlbWeight;
	//UILabel		*MlbStockMax;
	//UILabel		*MlbNeedMax;
	//UISlider			*MsliderStock;
	//UISlider			*MsliderNeed;
	AZDial			*mDialStock;
	AZDial			*mDialNeed;
#ifdef WEIGHT_DIAL
	AZDial			*mDialWeight;
#else
	UISlider			*MsliderWeight;
	UILabel		*MlbWeightMax;
	UILabel		*MlbWeightMin;
#endif
	
	CalcView		*McalcView;
	
	//----------------------------------------------assign
	AppDelegate		*appDelegate_;
	float						MfTableViewContentY;
}
@synthesize RaE2array;
@synthesize RaE3array;
@synthesize Re3target;
@synthesize PiAddGroup;
@synthesize PiAddRow;
@synthesize PbSharePlanList;
@synthesize delegate;
@synthesize selfPopover;


#pragma mark - dealloc

- (void)dealloc    // 生成とは逆順に解放するのが好ましい
{
	[selfPopover release], selfPopover = nil;
	[Re3target release];
	[RaE3array release];
	[RaE2array release];
	[super dealloc];
}


#pragma mark - View lifecicle

// UITableViewインスタンス生成時のイニシャライザ　viewDidLoadより先に1度だけ通る
- (id)initWithStyle:(UITableViewStyle)style 
{
	if ((self = [super initWithStyle:UITableViewStyleGrouped])) {  // セクションありテーブル
		// 初期化成功
		appDelegate_ = (AppDelegate *)[[UIApplication sharedApplication] delegate];
		appDelegate_.AppUpdateSave = NO;
		PbSharePlanList = NO;
		MfTableViewContentY = -1;

		if (appDelegate_.app_is_iPad) {
			self.contentSizeForViewInPopover = GD_POPOVER_E3detailTVC_SIZE;
			//[1.1]//[self.tableView setScrollEnabled:NO]; // スクロール禁止
		}
	}
	return self;
}

// IBを使わずにviewオブジェクトをプログラム上でcreateするときに使う（viewDidLoadは、nibファイルでロードされたオブジェクトを初期化するために使う）
- (void)loadView
{	//【Tips】ここでaddSubviewするオブジェクトは全てautoreleaseにすること。メモリ不足時には自動的に解放後、改めてここを通るので、初回同様に生成するだけ。
	[super loadView];

	// Set up NEXT Left [Back] buttons.
	self.navigationItem.backBarButtonItem  = [[[UIBarButtonItem alloc]
											   initWithTitle:NSLocalizedString(@"Cancel", nil)
											   style:UIBarButtonItemStylePlain 
											   target:nil  action:nil] autorelease];
	
	// CANCELボタンを左側に追加する  Navi標準の戻るボタンでは cancel:処理ができないため
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc]
											  initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
											  target:self action:@selector(cancelClose:)] autorelease];
	
	if (PbSharePlanList==NO) {
		// SAVEボタンを右側に追加する
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] 
												   initWithBarButtonSystemItem:UIBarButtonSystemItemSave
												   target:self action:@selector(saveClose:)] autorelease];
	}
}

- (void)viewDidLoad 
{
	[super viewDidLoad];
	// listen to our app delegates notification that we might want to refresh our detail view
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshAllViews:) name:NFM_REFRESH_ALL_VIEWS
											   object:[[UIApplication sharedApplication] delegate]];
}

- (void)viewDidUnload 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[super viewDidUnload];
}

// 他のViewやキーボードが隠れて、現れる都度、呼び出される
- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];

	self.navigationItem.rightBarButtonItem.enabled = appDelegate_.AppUpdateSave;

	// 電卓が出ておれば消す
	if (McalcView && [McalcView isShow]) {
		[McalcView hide]; //　ここでは隠すだけ。 removeFromSuperviewするとアニメ無く即消えてしまう。
	}
	
	// 画面表示に関係する Option Setting を取得する
	//NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	[self viewDesign]; // 下層で回転して戻ったときに再描画が必要
	// テーブルビューを更新します。
    //[self.tableView reloadData];
	//[self.tableView flashScrollIndicators]; // Apple基準：スクロールバーを点滅させる
}

- (void)viewDesign
{
	// 回転によるリサイズ
	CGRect rect;
	float fWidth = self.tableView.frame.size.width;
	
	rect = MlbGroup.frame;
	rect.size.width = fWidth - 80;
	MlbGroup.frame = rect;
	
	rect = MtfName.frame;
	rect.size.width = fWidth - 60;
	MtfName.frame = rect;
	
	rect = MtvNote.frame;
	rect.size.width = fWidth - 60;
	MtvNote.frame = rect;
	
	rect = MtfKeyword.frame;
	rect.size.width = fWidth - 60;
	MtfKeyword.frame = rect;
	
/*	rect = MlbStock.frame;
	rect.origin.x = fWidth / 2 - OFSX2;
	MlbStock.frame = rect;
	MlbNeed.frame = rect;
	MlbWeight.frame = rect;*/
	
	rect = mDialStock.frame;
	rect.size.width = fWidth - 80;
	[mDialStock setFrame:rect]; 	//NG//mDialStock.frame = rect;
	[mDialNeed setFrame:rect];
#ifdef WEIGHT_DIAL
	[mDialWeight setFrame:rect];
#else
	rect = MsliderStock.frame;
	rect.size.width = fWidth - 80;
	MsliderWeight.frame = rect;
#endif
	
/*	NSInteger iVal;
	iVal = [Re3target.stock integerValue];  //  MlbStock.text integerValue];
	MsliderStock.maximumValue = 10 + (iVal / 10) * 10;
	MlbStockMax.text = [NSString stringWithFormat:@"%4ld", (long)MsliderStock.maximumValue];
	MsliderStock.value = (float)iVal; // Min,Maxを変えてから、その範囲でしか代入できないため、最後に代入
	
	iVal = [Re3target.need integerValue];  // MlbNeed.text integerValue];
	MsliderNeed.maximumValue = 10 + (iVal / 10) * 10;
	MlbNeedMax.text = [NSString stringWithFormat:@"%4ld", (long)MsliderNeed.maximumValue];
	MsliderNeed.value = (float)iVal;
*/	
#ifdef WEIGHT_DIAL
#else
	NSInteger iVal;
	// One Weight
	iVal = [Re3target.weight integerValue];  // MlbWeight.text integerValue];
	// Min
	MsliderWeight.minimumValue = (float)(iVal - WEIGHT_CENTER_OFFSET);
	if (MsliderWeight.minimumValue < 0) MsliderWeight.minimumValue = 0.0f;
	MlbWeightMin.text = [NSString stringWithFormat:@"%ld", (long)MsliderWeight.minimumValue];
	// Max										  //  ↑左寄せにつき数字不要
	MsliderWeight.maximumValue = (float)(iVal + WEIGHT_CENTER_OFFSET);
	if (WEIGHT_MAX < MsliderWeight.maximumValue) MsliderWeight.maximumValue = WEIGHT_MAX;
	MlbWeightMax.text = [NSString stringWithFormat:@"%5ld", (long)MsliderWeight.maximumValue];
	// Value
	MsliderWeight.value = (float)iVal;
#endif
	
/*	rect = MlbStockMax.frame;
	rect.origin.x = fWidth - OFSX1;
	MlbStockMax.frame = rect;
	MlbNeedMax.frame = rect;
	MlbWeightMax.frame = rect;
 */
}

- (void)performNameFirstResponder
{
	if (MtfName && [MtfName.text length]<=0) {			// ブランクならば、
		[MtfName becomeFirstResponder];  // キーボード表示  NG/iPadでは効かなかった。0.5秒後にするとOK
	}
}

// ビューが最後まで描画された後やアニメーションが終了した後にこの処理が呼ばれる
- (void)viewDidAppear:(BOOL)animated 
{
    [super viewDidAppear:animated];
	[self.navigationController setToolbarHidden:YES animated:animated]; // ツールバー消す
	
	if (appDelegate_.app_is_Ad) {
		// 各viewDidAppear:にて「許可/禁止」を設定する
		[appDelegate_ AdRefresh:NO];	//広告禁止
	}

	//この時点で MtfName は未生成だから、0.5秒後に処理する
	[self performSelector:@selector(performNameFirstResponder) withObject:nil afterDelay:0.5f]; // 0.5秒後に呼び出す
}

// ビューが非表示にされる前や解放される前ににこの処理が呼ばれる
- (void)viewWillDisappear:(BOOL)animated 
{
	if (appDelegate_.app_is_iPad) {
		//
	} else {
		if (McalcView) {	// あれば破棄する
			[McalcView hide];
			[McalcView removeFromSuperview];  // これでCalcView.deallocされる
			//[McalcView release]; +1残っているが、viewが破棄されるときにreleseされるので、ここは不要
			McalcView = nil;
		}
	}
	[super viewWillDisappear:animated];
}


#pragma mark  View Rotate

// 回転サポート
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{	
	if (appDelegate_.app_is_iPad) {
		return YES;	// Popover内につき回転不要だが、NO にすると Shopping(Web)から戻ると強制的にタテ向きになってしまう。
	} else {
		// 回転禁止の場合、万一ヨコからはじまった場合、タテにはなるようにしてある。
		return appDelegate_.AppShouldAutorotate OR (interfaceOrientation == UIInterfaceOrientationPortrait);
	}
}

// ユーザインタフェースの回転を始める前にこの処理が呼ばれる。 ＜＜OS 3.0以降の推奨メソッド＞＞
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)orientation duration:(NSTimeInterval)duration
{
	// この開始時に消す。　　この時点で self.view.frame は回転していない。
	if (McalcView && [McalcView isShow]) {
		[McalcView hide]; //　ここでは隠すだけ。 removeFromSuperviewするとアニメ無く即消えてしまう。
	}
}

// ユーザインタフェースの回転の最後の半分が始まる前にこの処理が呼ばれる　＜＜このタイミングで配置転換すると見栄え良い＞＞
- (void)willAnimateSecondHalfOfRotationFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation 
													   duration:(NSTimeInterval)duration
{
	//[self.tableView reloadData];
	[self viewDesign]; // cell生成の後
}


#pragma mark - iCloud
- (void)refreshAllViews:(NSNotification*)note 
{	// iCloud-CoreData に変更があれば呼び出される
    //if (note) {
		[self.tableView reloadData];
		//[self viewWillAppear:YES];
    //}
}


#pragma mark - Action

- (void)cancelClose:(id)sender 
{	// E3は、Cancel時、新規ならば破棄、修正ならば復旧、させる
	if (Re3target && PbSharePlanList==NO) {  // Sample表示のときrollbackすると、一時表示用のE1まで消えてしまうので回避する。
		// ROLLBACK
#ifdef xxxDEBUG
		NSManagedObjectContext *moc = Re3target.managedObjectContext;
		//NSLog(@"--1-- Re3target=%@", Re3target);
		//[1.0.6]insertされたentityが本当にrollbackされているのかを検証
		{
			E2 *e2 = Re3target.parent;
			NSLog(@"--1-- [[e2.childs allObjects] count]=%d", (int)[[e2.childs allObjects] count]);
			
			NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
			NSEntityDescription *entity = [NSEntityDescription entityForName:@"E3" inManagedObjectContext:moc];
			[fetchRequest setEntity:entity];
			NSArray *arFetch = [moc executeFetchRequest:fetchRequest error:nil];
			NSLog(@"--1-- E3 count=%d", (int)[arFetch count]); //＜＜ New Goods CANCEL時、insertNewされたものが増えている。
			[fetchRequest release];
		}
#endif		

		//[1.0.6]今更ながら、insert後、saveしていない限り、rollbackだけで十分であることが解った。 ＜＜前後のDEBUGによる検証済み。
		[Re3target.managedObjectContext rollback]; // 前回のSAVE以降を取り消す
		
#ifdef xxxDEBUG
		//NSLog(@"--2-- Re3target=%@", Re3target);
		//[1.0.6]insertされたentityが本当にrollbackされているのかを検証
		{
			E2 *e2 = Re3target.parent;
			NSLog(@"--2-- [[e2.childs allObjects] count]=%d", (int)[[e2.childs allObjects] count]);
			
			NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
			NSEntityDescription *entity = [NSEntityDescription entityForName:@"E3" inManagedObjectContext:moc];
			[fetchRequest setEntity:entity];
			NSArray *arFetch = [moc executeFetchRequest:fetchRequest error:nil];
			NSLog(@"--2-- E3 count=%d", (int)[arFetch count]); //＜＜ New Goods CANCEL時、--1-- E3 count より1つ減っていることを確認した。
			[fetchRequest release];
		}
#endif		
		
	}

	if (appDelegate_.app_is_iPad) {
		if (selfPopover) {
			[selfPopover dismissPopoverAnimated:YES];
		}
	} else {
		[self.navigationController popViewControllerAnimated:YES];	// < 前のViewへ戻る
	}
}

// 編集フィールドの値を self.e3target にセットする
- (void)saveClose:(id)sender 
{
	if (PbSharePlanList) return; // [Save]ボタンを消しているので通らないハズだが、念のため。
	
	if (appDelegate_.app_is_iPad) {
	} else {
		//[McalcView hide]; // 電卓が出ておれば消す
		if (McalcView) {	// あれば破棄する
			[McalcView save]; // 有効値あれば保存
		}
	}
	
	NSInteger lWeight = [Re3target.weight integerValue];  // MlbWeight.text integerValue];
	NSInteger lStock = [Re3target.stock integerValue];  // MlbStock.text integerValue];
	NSInteger lNeed = [Re3target.need integerValue];  // MlbNeed.text integerValue];
	//[0.2c]プラン総重量制限
	if (0 < lWeight) {  // longオーバーする可能性があるため商は求めない
		if (AzMAX_PLAN_WEIGHT / lWeight < lStock OR AzMAX_PLAN_WEIGHT / lWeight < lNeed) {
			[self alertWeightOver];
			return;
		}
	}
	
	//Pe3target,Pe2selected は ManagedObject だから更新すれば ManagedObjectContext に反映される
	// PICKER 指定したコンポーネントで選択された行のインデックスを返す。
	NSInteger newSection = MlbGroup.tag;
	if ([self.RaE2array count]<=newSection) {
		NSLog(@"*** OVER newSection=%d", newSection);
		return;
	}
	E2 *e2objNew = [self.RaE2array objectAtIndex:newSection];
	
	if (self.PiAddGroup < 0 && 0 <= newSection)
	{	// Edit mode のときだけ、グループ移動による「旧グループの再集計」が必要になる
		NSInteger oldSection = [Re3target.parent.row integerValue];  // Edit mode
		
		if (oldSection != newSection) 
		{	// グループに変化があれば、
			// E2セクション(Group)の変更あり  self.e3section ==>> newSection
			NSInteger oldRow = [Re3target.row integerValue];	// 元ノードのrow　最後のrow更新処理で、ie3nodeRow以降を更新する。
			
			NSInteger newRow = (-1);
			// Add行に追加する （Add行は1つ下へ）
			for (E3* e3 in [self.RaE3array objectAtIndex:newSection]) {
				if ([e3.need integerValue]==(-1)) { // Add行
					newRow = [e3.row integerValue];
				}
			}
			if (newRow<0) {	// 万一、Add行がバグで削除されたときのため
				newRow = [[self.RaE3array objectAtIndex:newSection] count];  // セクション末尾
			}
			
			E2 *e2objOld = [self.RaE2array objectAtIndex:oldSection];
			//--------------------------------------------------(1)MutableArrayの移動
			[[self.RaE3array objectAtIndex:oldSection] removeObjectAtIndex:oldRow];
			[[self.RaE3array objectAtIndex:newSection] insertObject:Re3target atIndex:newRow];
			
			// 異セクション間の移動　＜＜親(.e2selected)の変更が必要＞＞
			// 移動元セクション（親）から子を削除する
			[e2objOld removeChildsObject:Re3target];	// 元の親ノードにある子登録を抹消する
			// e2objOld 子が無くなったので再集計する
			[e2objOld setValue:[e2objOld valueForKeyPath:@"childs.@sum.noGray"] forKey:@"sumNoGray"];
			[e2objOld setValue:[e2objOld valueForKeyPath:@"childs.@sum.noCheck"] forKey:@"sumNoCheck"];
			[e2objOld setValue:[e2objOld valueForKeyPath:@"childs.@sum.weightStk"] forKey:@"sumWeightStk"];
			[e2objOld setValue:[e2objOld valueForKeyPath:@"childs.@sum.weightNed"] forKey:@"sumWeightNed"];
			// 異動先セクション（親）へ子を追加する
			[e2objNew addChildsObject:Re3target];	// 新しい親ノードに子登録する
			// e2objNew の再集計は、変更を含めて最後に実施
			
			// 元のrow付け替え処理　 異セクション間での移動： 双方のセクションで変化あったrow以降、全て更新
			NSInteger i;
			E3 *e3obj;
			for (i = oldRow ; i < [[self.RaE3array objectAtIndex:oldSection] count] ; i++) {
				e3obj = [[self.RaE3array objectAtIndex:oldSection] objectAtIndex:i];
				e3obj.row = [NSNumber numberWithInteger:i];
			}
			// Add行に追加
			Re3target.row = [NSNumber numberWithInteger:newRow];  
			// Add行以下のrow付け替え処理
			for (i = newRow ; i < [[self.RaE3array objectAtIndex:newSection] count] ; i++) {
				e3obj = [[self.RaE3array objectAtIndex:newSection] objectAtIndex:i];
				e3obj.row = [NSNumber numberWithInteger:i];
			}
		}
	}
	
	if( 50 < [MtfName.text length] ){
		// 長さが50超ならば、0文字目から50文字を切り出して保存　＜以下で切り出すとフリーズする＞
		[Re3target setValue:[MtfName.text substringWithRange:NSMakeRange(0, 50)] forKey:@"name"];
	} else {
		//[Pe3target setValue:MlbName.text forKey:@"name"];
		Re3target.name = MtfName.text;
	}
	
	if( 50 < [MtfKeyword.text length] ){
		// 長さが50超ならば、0文字目から50文字を切り出して保存　＜以下で切り出すとフリーズする＞
		[Re3target setValue:[MtfKeyword.text substringWithRange:NSMakeRange(0, 50)] forKey:@"shopKeyword"];
	} else {
		Re3target.shopKeyword = MtfKeyword.text;
	}
	
	NSString *zNote;
	zNote = MtvNote.text;
	/*
	 if ([MlbNote.text length] <= 0) {
	 zNote = @"";
	 } 
	 else if (0 < [LABEL_NOTE_SUFFIX length]) {
	 // 末尾改行文字("\n")を PiSuffixLength 個除く -->> doneにて追加する
	 zNote = [MlbNote.text substringToIndex:([MlbNote.text length] - [LABEL_NOTE_SUFFIX length])];
	 } else {
	 zNote = MlbNote.text;
	 }
	 */
	if( TEXTVIEW_MAXLENGTH < [zNote length] ){
		// 長さがTEXTVIEW_MAXLENGTH超ならば、0文字目からTEXTVIEW_MAXLENGTH文字を切り出して保存　＜以下で切り出すとフリーズする＞
		[Re3target setValue:[zNote substringWithRange:NSMakeRange(0, TEXTVIEW_MAXLENGTH)] forKey:@"note"];
	} else {
		[Re3target setValue:zNote forKey:@"note"];
	}
	
	[Re3target setValue:[NSNumber numberWithInteger:lWeight] forKey:@"weight"];  // 最小値が0でないとエラー発生
	[Re3target setValue:[NSNumber numberWithInteger:lStock] forKey:@"stock"];
	[Re3target setValue:[NSNumber numberWithInteger:lNeed] forKey:@"need"];
	[Re3target setValue:[NSNumber numberWithInteger:(lWeight*lStock)] forKey:@"weightStk"];
	[Re3target setValue:[NSNumber numberWithInteger:(lWeight*lNeed)] forKey:@"weightNed"];
	[Re3target setValue:[NSNumber numberWithInteger:(lNeed-lStock)] forKey:@"lack"]; // 不足数
	[Re3target setValue:[NSNumber numberWithInteger:((lNeed-lStock)*lWeight)] forKey:@"weightLack"]; // 不足重量
	
	NSInteger iNoGray = 0;
	if (0 < lNeed) iNoGray = 1;
	[Re3target setValue:[NSNumber numberWithInteger:iNoGray] forKey:@"noGray"]; // NoGray:有効(0<必要数)アイテム
	
	NSInteger iNoCheck = 0;
	if (0 < lNeed && lStock < lNeed) iNoCheck = 1;
	[Re3target setValue:[NSNumber numberWithInteger:iNoCheck] forKey:@"noCheck"]; // NoCheck:不足アイテム
	
	if (0 <= self.PiAddGroup && 0 <= PiAddRow) {
		/*(V0.4)PiAddRow に新規追加する。 PiAddRow以下を先にずらすこと。
		 // 新規のとき、末尾になるように行番号を付与する
		 NSInteger rows = [[Pe3array objectAtIndex:newSection] count]; // 追加するセクションの現在行数
		 [Pe3target setValue:[NSNumber numberWithInteger:rows] forKey:@"row"];
		 // 親(E2)のchilesにe3editを追加する
		 [e2objNew addChildsObject:Pe3target];
		 */
		
		//(V0.4)PiAddRow以下について、.row++ して、PiAddRowを空ける。
		//		NSArray *aE3s = [NSArray arrayWithArray:[Pe3array objectAtIndex:newSection]];
		for (E3 *e3 in [RaE3array objectAtIndex:newSection]) {
			if (PiAddRow <= [e3.row integerValue]) {
				e3.row = [NSNumber numberWithInteger:[e3.row integerValue]+1]; // +1
			}
		}
		//(V0.4)PiAddRowに追加する。
		Re3target.row = [NSNumber numberWithInteger:PiAddRow];
		// E2-E3 Link
		Re3target.parent = e2objNew;
	}
	
	// E2 sum属性　＜高速化＞ 親sum保持させる
	[e2objNew setValue:[e2objNew valueForKeyPath:@"childs.@sum.noGray"] forKey:@"sumNoGray"];
	[e2objNew setValue:[e2objNew valueForKeyPath:@"childs.@sum.noCheck"] forKey:@"sumNoCheck"];
	[e2objNew setValue:[e2objNew valueForKeyPath:@"childs.@sum.weightStk"] forKey:@"sumWeightStk"];
	[e2objNew setValue:[e2objNew valueForKeyPath:@"childs.@sum.weightNed"] forKey:@"sumWeightNed"];
	
	// E1 sum属性　＜高速化＞ 親sum保持させる
	E1 *e1obj = e2objNew.parent;
	[e1obj setValue:[e1obj valueForKeyPath:@"childs.@sum.sumNoGray"] forKey:@"sumNoGray"];
	[e1obj setValue:[e1obj valueForKeyPath:@"childs.@sum.sumNoCheck"] forKey:@"sumNoCheck"];
	NSNumber *sumWeStk = [e1obj valueForKeyPath:@"childs.@sum.sumWeightStk"];
	NSNumber *sumWeNed = [e1obj valueForKeyPath:@"childs.@sum.sumWeightNed"];
	//[0.2c]プラン総重量制限
	if (AzMAX_PLAN_WEIGHT < [sumWeStk integerValue] OR AzMAX_PLAN_WEIGHT < [sumWeNed integerValue]) {
		[self alertWeightOver];
		return;
	}
	[e1obj setValue:sumWeStk forKey:@"sumWeightStk"];
	[e1obj setValue:sumWeNed forKey:@"sumWeightNed"];
	
	if (PbSharePlanList==NO) {  // SpMode=YESならば[SAVE]ボタンを非表示にしたので通らないハズだが、念のため。
		// SAVE : e3edit,e2list は ManagedObject だから更新すれば ManagedObjectContext に反映されている
		NSError *err = nil;
		if (![Re3target.managedObjectContext save:&err]) {
			NSLog(@"Unresolved error %@, %@", err, [err userInfo]);
			//abort();
		}
	}
	
	if (appDelegate_.app_is_iPad) {
		//[(PadNaviCon*)self.navigationController dismissPopoverSaved];  // SAVE: PadNaviCon拡張メソッド
		if (selfPopover) {
			if ([delegate respondsToSelector:@selector(refreshE3view)]) {	// メソッドの存在を確認する
				[delegate refreshE3view];// 親の再描画を呼び出す
			}
			[selfPopover dismissPopoverAnimated:YES];
		}
	} else {
		[self.navigationController popViewControllerAnimated:YES];	// < 前のViewへ戻る
	}
	
	// 必要数0が追加された場合、前に戻ったときに追加失敗している錯覚をおこさないように通知する
	if (lNeed <= 0) 
	{
		if ([[NSUserDefaults standardUserDefaults] boolForKey:GD_OptItemsGrayShow] == NO) 
		{
			UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Added Item",nil)
															 message:NSLocalizedString(@"GrayHiddon Alert",nil)
															delegate:nil 
												   cancelButtonTitle:nil 
												   otherButtonTitles:@"OK", nil] autorelease];
			[alert show];
		}
	}
}

- (void)closePopover
{
	if (selfPopover) {	//dismissPopoverCancel
		if (McalcView && [McalcView isShow]) {
			[McalcView cancel];  //　ラベル表示を元に戻す
		}
		[selfPopover dismissPopoverAnimated:YES];
	}
}

#pragma mark - CalcRoll

- (void)showCalc:(UILabel *)pLabel 
		  forKey:(NSString *)zKey 
		forTitle:(NSString *)zTitle
		 withRow:(NSInteger)iRow
		 withMax:(NSInteger)iMax
{
	if (McalcView) {	// あれば一旦、破棄する
		[McalcView hide];
		[McalcView removeFromSuperview];  // これでCalcView.deallocされる
		//[McalcView release]; +1残っているが、viewが破棄されるときにreleseされるので、ここは不要
		McalcView = nil;
	}
	[MtfName resignFirstResponder]; // ファーストレスポンダでなくす ⇒ キーボード非表示
	[MtvNote resignFirstResponder]; // ファーストレスポンダでなくす ⇒ キーボード非表示
	[MtfKeyword resignFirstResponder]; // ファーストレスポンダでなくす ⇒ キーボード非表示
	
	CGRect rect = self.view.bounds;

	if (appDelegate_.app_is_iPad) {
		//テンキー表示位置
		rect.origin.y = 400;  //全体が見えるようにした + (iRow-3)*60;  
	} else {
		MfTableViewContentY = self.tableView.contentOffset.y; // Hide時に元の表示に戻すため
		if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
			// 横
			rect.origin.y = 170 + (iRow-3)*60;
		}
		else {
			// 縦
			rect.origin.y = 78 + (iRow-3)*60;
		}
		// アニメ準備
		CGContextRef context = UIGraphicsGetCurrentContext();
		[UIView beginAnimations:nil context:context];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
		[UIView setAnimationDuration:0.3]; // 出は早く
		// アニメ終了位置
		self.tableView.contentOffset = CGPointMake(0, rect.origin.y);
		// アニメ実行
		[UIView commitAnimations];
	}
	
	McalcView = [[CalcView alloc] initWithFrame:rect];
	McalcView.Rlabel = pLabel;  // MlbAmount.tag にはCalc入力された数値(long)が記録される
	McalcView.Rentity = Re3target;
	McalcView.RzKey = zKey;
	McalcView.delegate = self;
	McalcView.maxValue = iMax;
	[self.view addSubview:McalcView];
	[McalcView release]; // addSubviewにてretain(+1)されるため、こちらはrelease(-1)して解放
	[McalcView show];
}

#pragma mark  <CalcViewDelegate>
//============================================<CalcViewDelegate>
- (void)calcViewWillAppear	// CalcViewが現れる直前に呼び出される
{
	[self.tableView setScrollEnabled:NO]; // スクロール禁止
}

- (void)calcViewWillDisappear	// CalcViewが隠れるときに呼び出される
{
	[self.tableView setScrollEnabled:YES]; // スクロール許可
	if (0 <= MfTableViewContentY) {
		// AzPacking Original 元の位置に戻す
		self.tableView.contentOffset = CGPointMake(0, MfTableViewContentY);
	}
	[mDialStock setDial:[Re3target.stock integerValue] animated:YES];
	[mDialNeed setDial:[Re3target.need integerValue] animated:YES];
#ifdef WEIGHT_MAX
	[mDialWeight setDial:[Re3target.weight integerValue] animated:YES];
#else
	[self viewWillAppear:NO]; // スライドバーを再描画するため
#endif
	
	self.navigationItem.rightBarButtonItem.enabled = appDelegate_.AppUpdateSave;
}


#pragma mark - TableView Cell

- (void)cellButtonCalc: (UIButton *)button 
{
	//assert(self.editing);
	//if (![self becomeFirstResponder]) return;
	
	//bu.tag = indexPath.section * GD_SECTION_TIMES + indexPath.row;
	NSInteger iSection = button.tag / GD_SECTION_TIMES;
	NSInteger iRow = button.tag - (iSection * GD_SECTION_TIMES);
	AzLOG(@"cellButtonCalc .row=%ld", (long)iRow);
	
	switch (iRow) {
		case 3: // Stock
			[self showCalc:MlbStock forKey:@"stock" forTitle:NSLocalizedString(@"StockQty", nil) withRow:3 withMax:STOCK_MAX];
			break;
		case 4: // Need
			[self showCalc:MlbNeed forKey:@"need" forTitle:NSLocalizedString(@"Need Qty", nil) withRow:4 withMax:NEED_MAX];
			break;
		case 5: // Weight
			[self showCalc:MlbWeight forKey:@"weight" forTitle:NSLocalizedString(@"One Weight", nil) withRow:5 withMax:WEIGHT_MAX];
			break;
	}
}

/*****
- (void)slidStock:(UISlider *)slider
{
	long lVal = (long)(slider.value + 0.5f);
	if (9999 < lVal) lVal = 9999;
	if ([Re3target.stock longValue] != lVal) { // 変更あり
		MlbStock.text = GstringFromNumber([NSNumber numberWithInteger:lVal]);  //[NSString stringWithFormat:@"%5ld", lVal];
		Re3target.stock = [NSNumber numberWithInteger:lVal];
		appDelegate.AppUpdateSave = YES; // 変更あり
		self.navigationItem.rightBarButtonItem.enabled = appDelegate.AppUpdateSave;
	}
}

- (void)slidStockUp:(UISlider *)slider
{
	long lVal = (long)(slider.value + 0.5f);
	slider.minimumValue = 0;
	slider.value = lVal;
	lVal = 10 + (lVal / 10) * 10;
	if (9999 < lVal) lVal = 9999;
	slider.maximumValue = lVal;
	MlbStockMax.text = [NSString stringWithFormat:@"%4ld", lVal];
}

- (void)slidNeed:(UISlider *)slider
{
	long lVal = (long)(slider.value + 0.5f);
	if (9999 < lVal) lVal = 9999;
	if ([Re3target.need longValue] != lVal) { // 変更あり
		MlbNeed.text = GstringFromNumber([NSNumber numberWithInteger:lVal]);  //[NSString stringWithFormat:@"%5ld", lVal];
		Re3target.need = [NSNumber numberWithInteger:lVal];
		appDelegate.AppUpdateSave = YES; // 変更あり
		self.navigationItem.rightBarButtonItem.enabled = appDelegate.AppUpdateSave;
	}
}

- (void)slidNeedUp:(UISlider *)slider
{
	long lVal = (long)(slider.value + 0.5f);
	slider.minimumValue = 0;
	slider.value = lVal;
	lVal = 10 + (lVal / 10) * 10;
	if (9999 < lVal) lVal = 9999;
	slider.maximumValue = lVal;
	MlbNeedMax.text = [NSString stringWithFormat:@"%4ld", lVal];
}
 *****/

#ifdef WEIGHT_DIAL
#else
- (void)slidWeight:(UISlider *)slider
{
	long lVal = (long)(slider.value + 0.5f);
	lVal = (lVal / WEIGHT_SLIDER_STEP) * WEIGHT_SLIDER_STEP;
	if (WEIGHT_MAX < lVal) lVal = WEIGHT_MAX;
	if ([Re3target.weight longValue] != lVal) { // 変更あり
		MlbWeight.text = GstringFromNumber([NSNumber numberWithInteger:lVal]);  //[NSString stringWithFormat:@"%5ld", lVal];
		Re3target.weight = [NSNumber numberWithInteger:lVal];
		appDelegate.AppUpdateSave = YES; // 変更あり
		self.navigationItem.rightBarButtonItem.enabled = appDelegate.AppUpdateSave;
	}	
}

- (void)slidWeightUp:(UISlider *)slider
{
	long lVal = (long)(slider.value + 0.5f);
	lVal = (lVal / WEIGHT_SLIDER_STEP) * WEIGHT_SLIDER_STEP;
	
	if (lVal <= WEIGHT_CENTER_OFFSET)
		slider.minimumValue = 0.0f;
	else
		slider.minimumValue = (float)(lVal - WEIGHT_CENTER_OFFSET);
	
	if (lVal < WEIGHT_MAX - WEIGHT_CENTER_OFFSET)
		slider.maximumValue = (float)(lVal + WEIGHT_CENTER_OFFSET);
	else
		slider.maximumValue = WEIGHT_MAX;
	// Minは、↓左寄せにつき数字不要
	MlbWeightMin.text = [NSString stringWithFormat:@"%ld", (long)slider.minimumValue];
	MlbWeightMax.text = [NSString stringWithFormat:@"%5ld", (long)slider.maximumValue];
}
#endif

- (void)alertWeightOver
{
	UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"WeightOver",nil)
													 message:NSLocalizedString(@"WeightOver message",nil)
													delegate:nil 
										   cancelButtonTitle:nil 
										   otherButtonTitles:@"OK", nil] autorelease];
	[alert show];
}


#pragma mark  <UITableViewDelegate>

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}



// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	switch (section) {
		case 0: // 
			return 6;
			break;
		case 1: // Shopping
			return 4;
			break;
	}
    return 0;
}

// TableView セクションタイトルを応答
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section 
{
	if (section==1) {
		return NSLocalizedString(@"Shopping", nil);
	}
	return nil;
}


// TableView セクションフッタを応答
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section 
{
	if (section==1) {
		return	@"\n\n\n\n\n"
		@"AzukiSoft Project\n"
		@"©1995-2011 Azukid"
		@"\n\n\n\n\n";
	}
	return nil;
}

// セルの高さを指示する
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (indexPath.section==0) {
		switch (indexPath.row) {
			case 2:
				if (appDelegate_.app_is_iPad) {
					return 150; // Note
				}
				return 110; // Note

			case 3:
			case 4:
			case 5:
				return 58;  // etc
		}
	}

	if (appDelegate_.app_is_iPad) {
		return 50;
	}
	return 44; // デフォルト：44ピクセル
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
    NSString *zCellIndex = [NSString stringWithFormat:@"E3detail%d:%d", (int)indexPath.section, (int)indexPath.row];
	UITableViewCell *cell = nil;

	cell = [tableView dequeueReusableCellWithIdentifier:zCellIndex];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									   reuseIdentifier:zCellIndex] autorelease];
		if (PbSharePlanList) {
			// 選択禁止
			cell.accessoryType = UITableViewCellAccessoryNone;
			cell.selectionStyle = UITableViewCellSelectionStyleNone; // 選択時ハイライトなし
		} else {
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;	// > ディスクロージャマーク
		}
		cell.showsReorderControl = NO; // Move禁止
	}
	else {
		return cell; // このTVではCell個体識別しているため
	}
	
	switch (indexPath.section) {
		case 0: // 
			if (3 <= indexPath.row) {  // stock, need, weight
				// Calcボタン ------------------------------------------------------------------
				UIButton *bu = [UIButton buttonWithType:UIButtonTypeCustom]; // autorelease
				bu.frame = CGRectMake(0,16, 44,44);
				[bu setImage:[UIImage imageNamed:@"Icon44-Calc.png"] forState:UIControlStateNormal];
				//[bu setImage:[UIImage imageNamed:@"Icon-ClipOn.png"] forState:UIControlStateHighlighted];
				//buClip.showsTouchWhenHighlighted = YES;
				bu.tag = indexPath.section * GD_SECTION_TIMES + indexPath.row;
				[bu addTarget:self action:@selector(cellButtonCalc:) forControlEvents:UIControlEventTouchUpInside];
				//[buCopy release]; buttonWithTypeにてautoreleseされるため不要。UIButtonにinitは無い。
				cell.accessoryView = bu;
				cell.accessoryType = UITableViewCellAccessoryNone;
				cell.selectionStyle = UITableViewCellSelectionStyleNone; // 選択時ハイライトなし
			}
			switch (indexPath.row) {
				case 0: // Group
				{
					UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(5,3, 100,12)];
					label.text = NSLocalizedString(@"Group", nil);
					label.textColor = [UIColor grayColor];
					label.backgroundColor = [UIColor clearColor];
					label.font = [UIFont systemFontOfSize:12];
					[cell.contentView addSubview:label]; [label release];

					if (appDelegate_.app_is_iPad) {
						MlbGroup = [[UILabel alloc] initWithFrame:
									CGRectMake(20,18, self.tableView.frame.size.width-60,24)];
						MlbGroup.font = [UIFont systemFontOfSize:20];
					} else {
						MlbGroup = [[UILabel alloc] initWithFrame:
									CGRectMake(20,18, self.tableView.frame.size.width-60,16)];
						MlbGroup.font = [UIFont systemFontOfSize:14];
					}
											   // cell.frame.size.width ではダメ。初期幅が常に縦になっているため
					// selectGroupTVC が MlbGroup を参照、変更する
					if (self.PiAddGroup < 0) {
						// Edit Mode
						MlbGroup.tag = [Re3target.parent.row integerValue]; // E2.row
						MlbGroup.text = Re3target.parent.name;
					} else {
						// Add Mode
						MlbGroup.tag = self.PiAddGroup; // E2.row
						MlbGroup.text = [[RaE2array objectAtIndex:self.PiAddGroup] valueForKey:@"name"];
					}
					if ([MlbGroup.text length] <= 0) { // (未定)
						MlbGroup.text = NSLocalizedString(@"(New Index)", nil);
					}
					MlbGroup.backgroundColor = [UIColor clearColor]; // [UIColor grayColor]; //範囲チェック用
					[cell.contentView addSubview:MlbGroup]; [MlbGroup release];
				}
					break;
				case 1: // Name
				{
					UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(5,3, 100,12)];
					label.font = [UIFont systemFontOfSize:12];
					label.text = NSLocalizedString(@"Item name", nil);
					label.textColor = [UIColor grayColor];
					label.backgroundColor = [UIColor clearColor];
					[cell.contentView addSubview:label]; [label release];

					if (appDelegate_.app_is_iPad) {
						MtfName = [[UITextField alloc] initWithFrame:
								   CGRectMake(20,18, self.tableView.frame.size.width-60,24)];
						MtfName.font = [UIFont systemFontOfSize:20];
					} else {
						MtfName = [[UITextField alloc] initWithFrame:
								   CGRectMake(20,18, self.tableView.frame.size.width-60,20)];
						MtfName.font = [UIFont systemFontOfSize:16];
					}
					MtfName.placeholder = NSLocalizedString(@"(New Goods)", nil);
					MtfName.keyboardType = UIKeyboardTypeDefault;
					MtfName.autocapitalizationType = UITextAutocapitalizationTypeSentences;
					MtfName.returnKeyType = UIReturnKeyDone; // ReturnキーをDoneに変える
					MtfName.backgroundColor = [UIColor clearColor]; //[UIColor grayColor]; //範囲チェック用
					MtfName.delegate = self; // textFieldShouldReturn:を呼び出すため
					[cell.contentView addSubview:MtfName]; [MtfName release];
					MtfName.text = Re3target.name; // (未定)表示しない。Editへ持って行かれるため
					cell.accessoryType = UITableViewCellAccessoryNone; // なし
				}
					break;
				case 2: // Note
				{
					UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(5,3, 100,12)];
					label.text = NSLocalizedString(@"Note", nil);
					label.textColor = [UIColor grayColor];
					label.backgroundColor = [UIColor clearColor];
					label.font = [UIFont systemFontOfSize:12];
					[cell.contentView addSubview:label]; [label release];

					if (appDelegate_.app_is_iPad) {
						MtvNote = [[UITextView alloc] initWithFrame:
								   CGRectMake(20,15, self.tableView.frame.size.width-60,130)];
						MtvNote.font = [UIFont systemFontOfSize:20];
					} else {
						MtvNote = [[UITextView alloc] initWithFrame:
								   CGRectMake(20,15, self.tableView.frame.size.width-60,95)];
						MtvNote.font = [UIFont systemFontOfSize:16];
					}
					MtvNote.textAlignment = UITextAlignmentLeft;
					MtvNote.keyboardType = UIKeyboardTypeDefault;
					MtvNote.returnKeyType = UIReturnKeyDefault;  //改行有効にする
					MtvNote.backgroundColor = [UIColor clearColor];
					//MtvNote.backgroundColor = [UIColor grayColor]; //範囲チェック用
					MtvNote.delegate = self;
					[cell.contentView addSubview:MtvNote]; [MtvNote release];
					if (Re3target.note == nil) {
						MtvNote.text = @"";  // TextViewは、(nil) と表示されるので、それを消すため。
					} else {
						MtvNote.text = Re3target.note;
					}
					cell.accessoryType = UITableViewCellAccessoryNone; // なし
				}
					break;
				case 3: // Stock
				{
#ifdef DEBUG
					//cell.backgroundColor = [UIColor grayColor]; //範囲チェック用
#endif
					{
						UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(30,2, 90,20)]; //(30,3, 90,20)
						label.text = NSLocalizedString(@"StockQty", nil);
						label.textAlignment = UITextAlignmentLeft;
						label.textColor = [UIColor grayColor];
						label.backgroundColor = [UIColor clearColor];
						label.font = [UIFont systemFontOfSize:14];
						[cell.contentView addSubview:label]; [label release];
					}
					long lVal = (long)[Re3target.stock integerValue];
					{
						MlbStock = [[UILabel alloc] initWithFrame:
									CGRectMake(self.tableView.frame.size.width-30-90,1, 90,20)];
						MlbStock.backgroundColor = [UIColor clearColor];
						MlbStock.textAlignment = UITextAlignmentRight;
						MlbStock.font = [UIFont systemFontOfSize:22];
						[cell.contentView addSubview:MlbStock]; [MlbStock release];
						//MlbStock.text = [NSString stringWithFormat:@"%5ld", lVal];
						// 3桁コンマ付加
						//NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
						//[formatter setNumberStyle:NSNumberFormatterDecimalStyle]; // CurrencyStyle]; // 通貨スタイル
						//MlbStock.text = [formatter stringFromNumber:Pe3target.stock];
						//[formatter release];
						MlbStock.text = GstringFromNumber(Re3target.stock);
					}
			/*		{
						MsliderStock = [[UISlider alloc] initWithFrame:
										CGRectMake(10,0, self.tableView.frame.size.width-80,60)];
						[MsliderStock addTarget:self action:@selector(slidStock:) forControlEvents:UIControlEventValueChanged];
						[MsliderStock addTarget:self action:@selector(slidStockUp:) forControlEvents:UIControlEventTouchUpInside];
						[cell.contentView addSubview:MsliderStock]; [MsliderStock release];
						MsliderStock.minimumValue = 0;
						MsliderStock.maximumValue = 10 + (lVal / 10) * 10;
						MsliderStock.value = lVal;
					}{
						UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10,40, 40,15)];
						label.textAlignment = UITextAlignmentLeft;
						label.textColor = [UIColor grayColor];
						label.backgroundColor = [UIColor clearColor];
						label.backgroundColor = [UIColor clearColor];
						label.font = [UIFont systemFontOfSize:12];
						label.text = @"0";
						[cell.contentView addSubview:label]; [label release];
					}{
						MlbStockMax = [[UILabel alloc] initWithFrame:
									   CGRectMake(self.tableView.frame.size.width-OFSX1,40, 40,15)];
						MlbStockMax.textAlignment = UITextAlignmentRight;
						MlbStockMax.textColor = [UIColor grayColor];
						MlbStockMax.backgroundColor = [UIColor clearColor];
						MlbStockMax.font = [UIFont systemFontOfSize:12];
						[cell.contentView addSubview:MlbStockMax]; [MlbStockMax release];
						MlbStockMax.text = [NSString stringWithFormat:@"%4ld", (long)MsliderStock.maximumValue];
					}*/
					
					mDialStock = [[AZDial alloc] initWithFrame:CGRectMake(10,16, self.tableView.frame.size.width-80,44)
																		delegate:self  dial:lVal  min:0  max:9999  step:1  stepper:YES];
					mDialStock.backgroundColor = [UIColor clearColor];
					[cell.contentView addSubview:mDialStock];
					[mDialStock release];
				}
					break;
				case 4: // Need
				{
					{
						UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(120,2, 90,20)];
						label.text = NSLocalizedString(@"Need Qty", nil);
						label.textAlignment = UITextAlignmentLeft;
						label.textColor = [UIColor grayColor];
						label.backgroundColor = [UIColor clearColor];
						label.font = [UIFont systemFontOfSize:14];
						[cell.contentView addSubview:label]; [label release];
					}
					long lVal = (long)[Re3target.need integerValue];
					{
						MlbNeed = [[UILabel alloc] initWithFrame:CGRectMake(10, 2, 94, 20)];
									//CGRectMake(self.tableView.frame.size.width/2-OFSX2,1, 90,20)];
						MlbNeed.backgroundColor = [UIColor clearColor];
						MlbNeed.textAlignment = UITextAlignmentCenter;
						MlbNeed.font = [UIFont systemFontOfSize:24];
						[cell.contentView addSubview:MlbNeed]; [MlbNeed release];
						//MlbNeed.text = [NSString stringWithFormat:@"%5ld", lVal];
						// 3桁コンマ付加
						MlbNeed.text = GstringFromNumber(Re3target.need);
					}
			/*		{
						MsliderNeed = [[UISlider alloc] initWithFrame:
									   CGRectMake(10,0, self.tableView.frame.size.width-80,60)];
						[MsliderNeed addTarget:self action:@selector(slidNeed:) forControlEvents:UIControlEventValueChanged];
						[MsliderNeed addTarget:self action:@selector(slidNeedUp:) forControlEvents:UIControlEventTouchUpInside];
						[cell.contentView addSubview:MsliderNeed]; [MsliderNeed release];
						MsliderNeed.minimumValue = 0;
						MsliderNeed.maximumValue = 10 + (lVal / 10) * 10;;
						MsliderNeed.value = lVal;
					}{
						UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10,40, 40,15)];
						label.textAlignment = UITextAlignmentLeft;
						label.textColor = [UIColor grayColor];
						label.backgroundColor = [UIColor clearColor];
						label.font = [UIFont systemFontOfSize:12];
						label.text = @"0";
						[cell.contentView addSubview:label]; [label release];
					}{
						MlbNeedMax = [[UILabel alloc] initWithFrame:
									  CGRectMake(self.tableView.frame.size.width-OFSX1,40, 40,15)];
						MlbNeedMax.textAlignment = UITextAlignmentRight;
						MlbNeedMax.textColor = [UIColor grayColor];
						MlbNeedMax.backgroundColor = [UIColor clearColor];
						MlbNeedMax.font = [UIFont systemFontOfSize:12];
						[cell.contentView addSubview:MlbNeedMax]; [MlbNeedMax release];
						MlbNeedMax.text = [NSString stringWithFormat:@"%4ld", (long)MsliderNeed.maximumValue];
					}*/
					mDialNeed = [[AZDial alloc] initWithFrame:CGRectMake(10,16, self.tableView.frame.size.width-80,44)
													  delegate:self  dial:lVal  min:0  max:9999  step:1  stepper:YES];
					mDialNeed.backgroundColor = [UIColor clearColor];
					[cell.contentView addSubview:mDialNeed];
					[mDialNeed release];
				}
					break;
				case 5: // Weight
				{
					{
						UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(120,2, 90,20)];
						label.text = NSLocalizedString(@"One Weight", nil);
						label.textAlignment = UITextAlignmentLeft;
						label.textColor = [UIColor grayColor];
						label.backgroundColor = [UIColor clearColor];
						label.font = [UIFont systemFontOfSize:14];
						label.adjustsFontSizeToFitWidth = YES;
						label.minimumFontSize = 8;
						label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
						[cell.contentView addSubview:label]; [label release];
					}
					long lVal = (long)[Re3target.weight integerValue];
					{
						MlbWeight = [[UILabel alloc] initWithFrame:CGRectMake(10, 2, 94, 20)];
									 //CGRectMake(self.tableView.frame.size.width/2-OFSX2,1, 90,20)];
						MlbWeight.backgroundColor = [UIColor clearColor];
						MlbWeight.textAlignment = UITextAlignmentCenter;
						MlbWeight.font = [UIFont systemFontOfSize:24];
						[cell.contentView addSubview:MlbWeight]; [MlbWeight release];
						//MlbWeight.text = [NSString stringWithFormat:@"%5ld", lVal];
						// 3桁コンマ付加
						MlbWeight.text = GstringFromNumber(Re3target.weight);
					}
#ifdef WEIGHT_DIAL
					mDialWeight = [[AZDial alloc] initWithFrame:CGRectMake(10,16, self.tableView.frame.size.width-80,44)
													   delegate:self  dial:lVal  min:0  max:WEIGHT_MAX  step:10  stepper:YES];
					mDialWeight.backgroundColor = [UIColor clearColor];
					//[mDialWeight setStepperMagnification:10.0];
					[cell.contentView addSubview:mDialWeight];
					[mDialWeight release];
#else				
					{
						MsliderWeight = [[UISlider alloc] initWithFrame:
										 CGRectMake(10,0, self.tableView.frame.size.width-80,60)];
						[MsliderWeight addTarget:self action:@selector(slidWeight:) forControlEvents:UIControlEventValueChanged];
						[MsliderWeight addTarget:self action:@selector(slidWeightUp:) forControlEvents:UIControlEventTouchUpInside];
						[cell.contentView addSubview:MsliderWeight]; [MsliderWeight release];
						if (lVal <= WEIGHT_CENTER_OFFSET)
							MsliderWeight.minimumValue = 0.0f;
						else
							MsliderWeight.minimumValue = (float)(lVal - WEIGHT_CENTER_OFFSET);
						
						if (lVal < WEIGHT_MAX - WEIGHT_CENTER_OFFSET)
							MsliderWeight.maximumValue = (float)(lVal + WEIGHT_CENTER_OFFSET);
						else
							MsliderWeight.maximumValue = WEIGHT_MAX;
						//
						MsliderWeight.value = lVal;
					}{
						MlbWeightMin = [[UILabel alloc] initWithFrame:CGRectMake(10,40, 40,15)];
						MlbWeightMin.textAlignment = UITextAlignmentLeft;
						MlbWeightMin.textColor = [UIColor grayColor];
						MlbWeightMin.backgroundColor = [UIColor clearColor];
						MlbWeightMin.font = [UIFont systemFontOfSize:12];
						[cell.contentView addSubview:MlbWeightMin]; [MlbWeightMin release];
						MlbWeightMin.text = [NSString stringWithFormat:@"%ld", (long)MsliderWeight.minimumValue];
																		// ↑左寄せにつき数字不要
					}{
						MlbWeightMax = [[UILabel alloc] initWithFrame:
										CGRectMake(self.tableView.frame.size.width-OFSX1,40, 40,15)];
						MlbWeightMax.textAlignment = UITextAlignmentRight;
						MlbWeightMax.textColor = [UIColor grayColor];
						MlbWeightMax.backgroundColor = [UIColor clearColor];
						MlbWeightMax.font = [UIFont systemFontOfSize:12];
						[cell.contentView addSubview:MlbWeightMax]; [MlbWeightMax release];
						MlbWeightMax.text = [NSString stringWithFormat:@"%5ld", (long)MsliderWeight.maximumValue];
					}
#endif
				}
					break;
			}
			break;
			
		case 1:	// section 1: Shopping
			switch (indexPath.row) {
				case 0: // Keyword
				{
					UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(5,3, 100,12)];
					label.font = [UIFont systemFontOfSize:12];
					label.text = NSLocalizedString(@"Shop Keyword", nil);
					label.textColor = [UIColor grayColor];
					label.backgroundColor = [UIColor clearColor];
					[cell.contentView addSubview:label]; [label release];

					if (appDelegate_.app_is_iPad) {
						MtfKeyword = [[UITextField alloc] initWithFrame:
									  CGRectMake(20,18, self.tableView.frame.size.width-60,24)];
						MtfKeyword.font = [UIFont systemFontOfSize:20];
					} else {
						MtfKeyword = [[UITextField alloc] initWithFrame:
									  CGRectMake(20,18, self.tableView.frame.size.width-60,20)];
						MtfKeyword.font = [UIFont systemFontOfSize:16];
					}
					MtfKeyword.placeholder = NSLocalizedString(@"Shop Keyword placeholder", nil);
					MtfKeyword.keyboardType = UIKeyboardTypeDefault;
					MtfKeyword.autocapitalizationType = UITextAutocapitalizationTypeSentences;
					MtfKeyword.returnKeyType = UIReturnKeyDone; // ReturnキーをDoneに変える
					MtfKeyword.backgroundColor = [UIColor clearColor]; //[UIColor grayColor]; //範囲チェック用
					MtfKeyword.delegate = self; // textFieldShouldReturn:を呼び出すため
					[cell.contentView addSubview:MtfKeyword]; [MtfKeyword release];
					MtfKeyword.text = Re3target.shopKeyword; // (未定)表示しない。Editへ持って行かれるため
					cell.accessoryType = UITableViewCellAccessoryNone; // なし
					cell.tag = 00;
				}
					break;
				
				default:
				{
					cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
					cell.selectionStyle = UITableViewCellSelectionStyleBlue; // 選択時ハイライト
					if ([NSLocalizedString(@"CountryCode", nil) isEqualToString:@"jp"]) {
						switch (indexPath.row) {
							case 1: 
								cell.imageView.image = [UIImage imageNamed:@"Icon32-Amazon"];
								cell.textLabel.text = NSLocalizedString(@"Shop Amazon.co.jp", nil);	
								cell.tag = 01;		break;
							case 2: 
								cell.imageView.image = [UIImage imageNamed:@"Icon32-Rakuten"];
								cell.textLabel.text = NSLocalizedString(@"Shop Rakuten", nil);				
								cell.tag = 11;		break;
							case 3: 
								cell.imageView.image = [UIImage imageNamed:@"Icon32-Amazon"];
								cell.textLabel.text = NSLocalizedString(@"Shop Amazon.com", nil);	
								cell.tag = 02;		break;
						}
					} else {
						switch (indexPath.row) {
							case 1: 
								cell.imageView.image = [UIImage imageNamed:@"Icon32-Amazon"];
								cell.textLabel.text = NSLocalizedString(@"Shop Amazon.com", nil);	
								cell.tag = 02;		break;
							case 2: 
								cell.imageView.image = [UIImage imageNamed:@"Icon32-Amazon"];
								cell.textLabel.text = NSLocalizedString(@"Shop Amazon.co.jp", nil);	
								cell.tag = 01;		break;
							case 3: 
								cell.imageView.image = [UIImage imageNamed:@"Icon32-Rakuten"];
								cell.textLabel.text = NSLocalizedString(@"Shop Rakuten", nil);				
								cell.tag = 11;		break;
						}
					}
				}
					break;
			}
	}
    return cell;
}

- (void)actionWebTitle:(NSString*)zTitle  URL:(NSString*)zUrl  Domain:(NSString*)zDomain
{
	if ([MtfKeyword.text length]<=0) {
		MtfKeyword.text = MtfName.text;
		appDelegate_.AppUpdateSave = YES; // 変更あり
		self.navigationItem.rightBarButtonItem.enabled = appDelegate_.AppUpdateSave;
	}
	// 日本語を含むURLをUTF8でエンコーディングする
	// 第3引数のCFSTR(";,/?:@&=+$#")で指定した文字列はエンコードされずにそのまま残る
	NSString *zKeyword = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
																			 (CFStringRef)MtfKeyword.text,
																			 CFSTR(";,/?:@&=+$#"),
																			 NULL,
																			 kCFStringEncodingUTF8);	// release必要

	WebSiteVC *web = [[WebSiteVC alloc] init];
	web.title = zTitle;
	web.Rurl = [zUrl stringByAppendingString:zKeyword];
	web.RzDomain = zDomain;
	[zKeyword release], zKeyword = nil;

	if (appDelegate_.app_is_iPad) {
		UINavigationController* nc = [[UINavigationController alloc] initWithRootViewController:web];
		nc.modalPresentationStyle = UIModalPresentationPageSheet;  // 背景Viewが保持される
		// FullScreenにするとPopoverが閉じられる。さらに、背後が破棄されてE3viewController:viewWillAppear が呼び出されるようになる。
		nc.modalTransitionStyle = UIModalTransitionStyleCoverVertical;//	UIModalTransitionStyleFlipHorizontal
		//[self　 presentModalViewController:nc animated:YES];  NG//回転しない
		//[self.navigationController presentModalViewController:nc animated:YES];  NG//回転しない
		[appDelegate_.mainSVC presentModalViewController:nc animated:YES];  //回転する
		[nc release];
	} else {
		[self.navigationController pushViewController:web animated:YES];
	}
	[web release];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];	// 選択状態を解除する

	[MtfName resignFirstResponder]; // キーボード非表示
	[MtvNote resignFirstResponder]; // キーボード非表示
	[MtfKeyword resignFirstResponder]; // キーボード非表示
	
	switch (indexPath.section) {
		case 0: // 
			switch (indexPath.row) {
				case 0: // Group
				{
					// selectGroupTVC へ
					selectGroupTVC *selectGroup = [[selectGroupTVC alloc] init];
					selectGroup.RaE2array = RaE2array;
					selectGroup.RlbGroup = MlbGroup; // .tag=E2.row  .text=E2.name
					[self.navigationController pushViewController:selectGroup animated:YES];
					[selectGroup release];
				}
					break;
				case 1: // Name
				{
					[MtfName becomeFirstResponder]; // ファーストレスポンダにする ⇒ キーボード表示
				}
					break;
				case 2: // Note
				{
					[MtvNote becomeFirstResponder]; // ファーストレスポンダにする ⇒ キーボード表示
				}
					break;
			}
			break;
		
		case 1: {	// section 1: Shopping
			UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
			switch (cell.tag) {
				case 00: // Name
				{
					[MtfKeyword becomeFirstResponder]; // ファーストレスポンダにする ⇒ キーボード表示
				}
					break;
				case 01: // Amazon.co.jp
				{
					NSString *zUrl;
					if (appDelegate_.app_is_iPad) {
						// PCサイト　　　　URL表示するようになったので長くする＜＜TAGが見えないように
						// アソシエイトリンク作成方法⇒ https://affiliate.amazon.co.jp/gp/associates/help/t121/a1
						//www.amazon.co.jp/gp/search?ie=UTF8&keywords=[SEARCH_PARAMETERS]&tag=[ASSOCIATE_TAG]&index=blended&linkCode=ure&creative=6339
						zUrl = @"http://www.amazon.co.jp/s/?ie=UTF8&index=blended&linkCode=ure&creative=6339&tag=art063-22&keywords=";
					} else {
						// モバイルサイト　　　　　"ie=UTF8" が無いと日本語キーワードが化ける
						//www.amazon.co.jp/gp/aw/s/ref=is_s_?__mk_ja_JP=%83J%83%5E%83J%83i&k=[SEARCH_PARAMETERS]&url=search-alias%3Daps
						zUrl = @"http://www.amazon.co.jp/gp/aw/s/ref=is_s_?ie=UTF8&__mk_ja_JP=%83J%83%5E%83J%83i&url=search-alias%3Daps&at=art063-22&k=";
					}
					[self actionWebTitle:NSLocalizedString(@"Shop Amazon.co.jp", nil)
									 URL:zUrl
								  Domain:@".amazon.co.jp"];
				}
					break;
				case 02: // Amazon.com
				{
					NSString *zUrl;
					if (appDelegate_.app_is_iPad) {
						// PCサイト
						//www.amazon.com/s/?tag=azuk-20&creative=392009&campaign=212361&link_code=wsw&_encoding=UTF-8&search-alias=aps&field-keywords=LEGO&Submit.x=16&Submit.y=14&Submit=Go
						//NSString *zUrl = @"http://www.amazon.com/s/?tag=azuk-20&_encoding=UTF-8&k="; URL表示するようになったので長くする＜＜TAGが見えないように
						zUrl = @"http://www.amazon.com/s/?_encoding=UTF-8&search-alias=aps&creative=392009&campaign=212361&tag=azuk-20&field-keywords=";
					} else {
						// モバイルサイト
						//www.amazon.com/gp/aw/s/ref=is_box_?k=LEGO
						zUrl = @"http://www.amazon.com/gp/aw/s/ref=is_box_?_encoding=UTF-8&link_code=wsw&search-alias=aps&tag=azuk-20&k=";
					}
					[self actionWebTitle:NSLocalizedString(@"Shop Amazon.com", nil)
									 URL:zUrl
								  Domain:@".amazon.com"];
				}
					break;
				case 11: // 楽天 Search
				{			// アフィリエイトID(β版): &afid=0e4c9297.0f29bc13.0e4c9298.6adf8529
					NSString *zUrl;
					if (appDelegate_.app_is_iPad) {
						// PCサイト
						zUrl = @"http://search.rakuten.co.jp/search/mall/?sv=2&p=0&afid=0e4c9297.0f29bc13.0e4c9298.6adf8529&sitem=";
					} else {
						// モバイルサイト
						//http://search.rakuten.co.jp/search/spmall?sv=2&p=0&sitem=SG7&submit=商品検索&scid=af_ich_link_search&scid=af_ich_link_search
						zUrl = @"http://search.rakuten.co.jp/search/spmall/?sv=2&p=0&afid=0e4c9297.0f29bc13.0e4c9298.6adf8529&sitem=";
					}
					[self actionWebTitle:NSLocalizedString(@"Shop Rakuten", nil)
									 URL:zUrl
								  Domain:@".rakuten.co.jp"];
				}
					break;
				case 21: // ケンコーコム Search
				{			// アフィリエイトID
					NSString *zUrl = @"http://sp.kenko.com/";
					[self actionWebTitle:NSLocalizedString(@"Shop Kenko.com", nil)
									 URL:zUrl
								  Domain:@".kenko.com"];
				}
					break;
			}
		}
			break;
	}
}


#pragma mark - <UITextFieldDelegete>
//============================================<UITextFieldDelegete>
- (void)nameDone:(id)sender {
	[MtfName resignFirstResponder]; // キーボード非表示
	[MtvNote resignFirstResponder]; // キーボード非表示
	[MtfKeyword resignFirstResponder]; // キーボード非表示
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
	if (McalcView) {	// あれば一旦、破棄する
		[McalcView hide];
		[McalcView removeFromSuperview];  // これでCalcView.deallocされる
		McalcView = nil;
	}
	// スクロールして textField が隠れた状態で resignFirstResponder するとフリースするため
	self.tableView.scrollEnabled = NO; // スクロール禁止
	//self.navigationItem.leftBarButtonItem.enabled = NO;
	if (appDelegate_.app_is_iPad) {
		//iPad：キー操作でキーボードを隠すことができるから[Done]ボタン不要
	} else {
		// 左[Cancel] 無効にする
		self.navigationItem.leftBarButtonItem.enabled = NO;
		// 右[Done]
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] 
												   initWithBarButtonSystemItem:UIBarButtonSystemItemDone
												   target:self action:@selector(nameDone:)] autorelease];
	}
}

//  テキストが変更される「直前」に呼び出される。これにより入力文字数制限を行っている。
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
	// senderは、MtextView だけ
    NSMutableString *zText = [[textField.text mutableCopy] autorelease];
    [zText replaceCharactersInRange:range withString:string];
	// 置き換えた後の長さをチェックする
	if ([zText length] <= TEXTFIELD_MAXLENGTH) {
		appDelegate_.AppUpdateSave = YES; // 変更あり
		self.navigationItem.rightBarButtonItem.enabled = appDelegate_.AppUpdateSave;
		return YES;
	} else {
		return NO;
	}
}

- (BOOL)textFieldShouldReturn: (UITextField *)textField
{
	[textField resignFirstResponder]; // ファーストレスポンダでなくす ⇒ キーボード非表示
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	self.tableView.scrollEnabled = YES; // スクロール許可
	//self.navigationItem.leftBarButtonItem.enabled = YES;
	if (appDelegate_.app_is_iPad) {
		//iPad：キー操作でキーボードを隠すことができるから[Done]ボタン不要
	} else {
		// 左[Cancel] 有効にする
		self.navigationItem.leftBarButtonItem.enabled = YES;
		// 右[Save]
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] 
												   initWithBarButtonSystemItem:UIBarButtonSystemItemSave
												   target:self action:@selector(saveClose:)] autorelease];
	}
}


#pragma mark - <UITextViewDelegete>
//============================================<UITextViewDelegete>
- (void)noteDone:(id)sender {
	[MtvNote resignFirstResponder];
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
	if (McalcView) {	// あれば一旦、破棄する
		[McalcView hide];
		[McalcView removeFromSuperview];  // これでCalcView.deallocされる
		McalcView = nil;
	}
	self.tableView.scrollEnabled = NO; // スクロール禁止
	//self.navigationItem.leftBarButtonItem.enabled = NO;
	if (appDelegate_.app_is_iPad) {
		//iPad：キー操作でキーボードを隠すことができるから[Done]ボタン不要
	} else {
		// 左[Cancel] 無効にする
		self.navigationItem.leftBarButtonItem.enabled = NO;
		// 右[Done]
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] 
												   initWithBarButtonSystemItem:UIBarButtonSystemItemDone
												   target:self action:@selector(noteDone:)] autorelease];
	}
}

//  テキストが変更される「直前」に呼び出される。これにより入力文字数制限を行っている。
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range 
 replacementText:(NSString *)zReplace
{
	// senderは、MtextView だけ
    NSMutableString *zText = [[textView.text mutableCopy] autorelease];
    [zText replaceCharactersInRange:range withString:zReplace];
	// 置き換えた後の長さをチェックする
	if ([zText length] <= TEXTVIEW_MAXLENGTH) {
		appDelegate_.AppUpdateSave = YES; // 変更あり
		self.navigationItem.rightBarButtonItem.enabled = appDelegate_.AppUpdateSave;
		return YES;
	} else {
		return NO;
	}
}

//- (BOOL)textViewShouldEndEditing:(UITextView *)textView
- (void)textViewDidEndEditing:(UITextView *)textView
{
	self.tableView.scrollEnabled = YES; // スクロール許可
	//self.navigationItem.leftBarButtonItem.enabled = YES;
	if (appDelegate_.app_is_iPad) {
		//iPad：キー操作でキーボードを隠すことができるから[Done]ボタン不要
	} else {
		// 左[Cancel] 有効にする
		self.navigationItem.leftBarButtonItem.enabled = YES;
		// 右[Save]
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] 
												   initWithBarButtonSystemItem:UIBarButtonSystemItemSave
												   target:self action:@selector(saveClose:)] autorelease];
	}
}


#pragma mark - <AZDialDelegate>
- (void)dialChanged:(id)sender  dial:(NSInteger)dial
{
	if (sender==mDialStock) {
		MlbStock.text = GstringFromNumber([NSNumber numberWithInteger:dial]);
	}
	else if (sender==mDialNeed) {
		MlbNeed.text = GstringFromNumber([NSNumber numberWithInteger:dial]);
	}
#ifdef WEIGHT_DIAL
	else if (sender==mDialWeight) {
		MlbWeight.text = GstringFromNumber([NSNumber numberWithInteger:dial]);
	}
#endif
}

- (void)dialDone:(id)sender  dial:(NSInteger)dial
{
	if (sender==mDialStock) {
		if ([Re3target.stock longValue] != dial) { // 変更あり
			MlbStock.text = GstringFromNumber([NSNumber numberWithInteger:dial]);
			Re3target.stock = [NSNumber numberWithInteger:dial];
			appDelegate_.AppUpdateSave = YES; // 変更あり
			self.navigationItem.rightBarButtonItem.enabled = appDelegate_.AppUpdateSave;
		}
	}
	else if (sender==mDialNeed) {
		if ([Re3target.need longValue] != dial) { // 変更あり
			MlbNeed.text = GstringFromNumber([NSNumber numberWithInteger:dial]);
			Re3target.need = [NSNumber numberWithInteger:dial];
			appDelegate_.AppUpdateSave = YES; // 変更あり
			self.navigationItem.rightBarButtonItem.enabled = appDelegate_.AppUpdateSave;
		}
	}
#ifdef WEIGHT_DIAL
	else if (sender==mDialWeight) {
		if ([Re3target.weight longValue] != dial) { // 変更あり
			MlbWeight.text = GstringFromNumber([NSNumber numberWithInteger:dial]);
			Re3target.weight = [NSNumber numberWithInteger:dial];
			appDelegate_.AppUpdateSave = YES; // 変更あり
			self.navigationItem.rightBarButtonItem.enabled = appDelegate_.AppUpdateSave;
		}
	}
#endif
}


@end

