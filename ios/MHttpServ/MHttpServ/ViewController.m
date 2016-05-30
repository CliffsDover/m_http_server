//
//  ViewController.m
//  MHttpServ
//
//  Created by lalawue on 15/9/12.
//  Copyright (c) 2015年 onz. All rights reserved.
//

#import "ViewController.h"
#import "HTTPServViewController.h"

@implementation ViewController {
    NSString                *_dirPathPub, *_dirPathPriv;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.title = @"Choose Dir";
    self.view.backgroundColor = [UIColor whiteColor];

    _dirPathPub = [@"~/Library/Caches/DirPublic" stringByExpandingTildeInPath];
    _dirPathPriv = [@"~/Library/Caches/DirPrivate" stringByExpandingTildeInPath];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:_dirPathPub
                              withIntermediateDirectories:YES attributes:nil error:nil];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:_dirPathPriv
                              withIntermediateDirectories:YES attributes:nil error:nil];

    CGSize vsize = self.view.frame.size;

    // for dir pub
    UIButton *btnPub =
    [self createButton:CGRectMake(vsize.width/2-50, vsize.height/2-120, 100, 45)
                    title:@"Public Dir"];
    btnPub.tag = 1;
    [btnPub addTarget:self action:@selector(onBtn:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnPub];

    // for dir priv
    UIButton *btnPriv =
    [self createButton:CGRectMake(vsize.width/2-50, vsize.height/2-40, 100, 45)
                 title:@"Private Dir"];
    btnPriv.tag = 2;
    [btnPriv addTarget:self action:@selector(onBtn:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnPriv];
}

- (UIButton*)createButton:(CGRect)frame title:(NSString*)title {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateHighlighted];
    [btn setFrame:frame];
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [UIColor blackColor].CGColor;
    return btn;
}

- (void)onBtn:(UIButton*)btn {
    if (btn.tag==1 || btn.tag==2) {
        NSArray *dirPathAry = @[_dirPathPub, _dirPathPriv];
        
        HTTPServViewController *vc = [[HTTPServViewController alloc]init];
        vc.dirPath = dirPathAry[btn.tag - 1];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

@end
