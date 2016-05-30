//
//  HTTPServViewController.m
//  MHttpServ
//
//  Created by Lii on 16/5/30.
//  Copyright © 2016年 onz. All rights reserved.
//

#import "HTTPServViewController.h"
#import "MHTTPServ.h"

@interface FileItem : NSObject
@property (nonatomic) NSString      *fileName;
@property (nonatomic) uint64_t      fileSize;
@end
@implementation FileItem
@end

@interface HTTPServViewController () <UITableViewDelegate,UITableViewDataSource,MHTTPServDelegate>
@end

@implementation HTTPServViewController {
    UILabel                 *_infoLb;
    UITableView             *_tblView;
    NSMutableArray          *_itemAry;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"MHTTPServ";
    self.view.backgroundColor = [UIColor whiteColor];
    
    _itemAry = [NSMutableArray new];
    [MHTTPServ sharedIns].delegate = self;
    
    [self createTableView];
    [self createInfoView];
}

- (void)createTableView {
    _tblView = [[UITableView alloc] initWithFrame:(CGRect){0,0,self.view.frame.size} style:UITableViewStylePlain];
    _tblView.delegate = self;
    _tblView.dataSource = self;
    [self.view addSubview:_tblView];
    [_tblView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"HTTPServCell"];
}

- (void)createInfoView {
    CGSize vsize = self.view.frame.size;
    
    _infoLb = [[UILabel alloc] initWithFrame:(CGRect){15,vsize.height/2-50,vsize.width-30,45}];
    [self.view addSubview:_infoLb];
    
    UIView *progressView = [[UIView alloc] initWithFrame:(CGRect){0,0,.5,_infoLb.frame.size.height}];
    progressView.tag = 1;
    progressView.alpha = 0.3;
    progressView.backgroundColor = [UIColor greenColor];
    
    [_infoLb addSubview:progressView];
    _infoLb.hidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self reloadDirInfo];
    
    if ( [[MHTTPServ sharedIns] startServ:_dirPath onPort:1234] ) {
        
        NSString *msg = [NSString stringWithFormat:@"http://%@:1234", [MHTTPServ sharedIns].ipAddr];
        
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:nil message:msg delegate:self cancelButtonTitle:@"OK"
                                           otherButtonTitles:nil];
        [av show];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [[MHTTPServ sharedIns] stopServ];
}

#pragma mark - MHTTP Server

- (void)onMHTTPServEvent:(NSString *)errorMsg fileName:(NSString *)fileName fileSize:(int64_t)fileSize percent:(float)percent {
    if (errorMsg) {
        [self updateInfoView:errorMsg coverColor:[UIColor clearColor] percent:0];
        [UIView animateWithDuration:3. animations:^{
            
        } completion:^(BOOL finished){
            _infoLb.hidden = YES;
        }];
        return;
    }
    
    if (percent>0 && percent<=1.) {
        [self updateInfoView:[NSString stringWithFormat:@"%2.0f%%, (%.2fMb), %@", percent*100, (double)fileSize/(double)1048576, fileName]
                  coverColor:[UIColor greenColor] percent:percent];
        
        if (percent >= 1.) {
            [UIView animateWithDuration:3. animations:^{
                
            } completion:^(BOOL finished){
                [self reloadDirInfo];
                _infoLb.hidden = YES;
            }];
        }
    }
}

- (void)updateInfoView:(NSString*)infoMsg coverColor:(UIColor*)coverColor percent:(float)percent {
    _infoLb.hidden = NO;
    _infoLb.text = infoMsg;
    UIView *v = [_infoLb viewWithTag:1];
    if (v) {
        if (percent>0 && percent<=1.) {
            v.hidden = NO;
            v.backgroundColor = coverColor;
            v.frame = (CGRect){0,0,_infoLb.frame.size.width*percent,_infoLb.frame.size.height};
        }
        else if (percent<=0) {
            v.hidden = YES;
        }
    }
}

- (void)reloadDirInfo {
    [_itemAry removeAllObjects];
    [[MHTTPServ sharedIns] enumerateDir:_dirPath block:^BOOL(NSString *fileName, BOOL isDir, int64_t fileSize) {
        if (!isDir) {
            FileItem *item = [[FileItem alloc] init];
            item.fileName = fileName;
            item.fileSize = fileSize;
            [_itemAry addObject:item];
        }
        return YES;
    }];
    [_tblView reloadData];
}

#pragma mark - Table View

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _itemAry.count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"HTTPServCell"];
    if (indexPath.row < _itemAry.count) {
        FileItem *item = _itemAry[indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"(%.2fMb) %@", (double)item.fileSize/(double)1048576, item.fileName];
    }
    return cell;
}

@end
