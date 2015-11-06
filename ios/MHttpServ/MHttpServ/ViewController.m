//
//  ViewController.m
//  MHttpServ
//
//  Created by lalawue on 15/9/12.
//  Copyright (c) 2015年 onz. All rights reserved.
//

#import "ViewController.h"
#import "m_debug.h"
#import "plat_net.h"
#import "client_http_serv.h"

#include <ifaddrs.h>
#include <arpa/inet.h>

@interface ViewController () <UITableViewDataSource,UITableViewDelegate>
@end

@implementation ViewController {
    BOOL            _bRunning;
    char            _dataPath[MDIR_MAX_PATH];
    char            _ipAddr[64];
    FILE            *_fp;
    
    UITableView     *_tblView;
    __weak UIView   *_progressView;
    NSMutableArray  *_fileNameAry;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// from 'http://zachwaugh.me/posts/programmatically-retrieving-ip-address-of-iphone/'
- (NSString *)getIPAddress
{
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if( temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    // Free memory
    freeifaddrs(interfaces);
    
    return address;
}

static void _http_serv_cb(client_http_serv_state_t *st) {
    ViewController *vc = (__bridge ViewController*)st->opaque;
    [vc httpServCb:st];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.view.backgroundColor = [UIColor clearColor];

    NSString *path = [@"~/Documents/ServData" stringByExpandingTildeInPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    [path getCString:_dataPath maxLength:MDIR_MAX_PATH encoding:NSUTF8StringEncoding];
    
    NSString *ipAddr = [self getIPAddress];
    [ipAddr getCString:_ipAddr maxLength:64 encoding:NSUTF8StringEncoding];
    
    _fileNameAry = [NSMutableArray new];
    
    _tblView = [[UITableView alloc] initWithFrame:self.view.frame style:UITableViewStylePlain];
    _tblView.delegate = self;
    _tblView.dataSource = self;
    [self.view addSubview:_tblView];
}

#pragma mark - Networking

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    debug_open("stdout");
    mnet_init();
    
    client_http_serv_config_t conf;
    conf.port = 1234;
    conf.opaque = (__bridge void*)self;
    strcpy(conf.title, "Welcome to MHttpServ");
    strcpy(conf.dev_name, "Lalawue's iPad");
    strncpy(conf.ipaddr, _ipAddr, 64);
    strncpy(conf.dpath, _dataPath, MDIR_MAX_PATH);
    
    if (client_http_serv_open(&conf, _http_serv_cb)) {
        _bRunning = YES;
        [self performSelector:@selector(networkRunning) withObject:nil];
        
        [self reloadLocalData];
    }

}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    _bRunning = NO;
    client_http_serv_close();
    mnet_fini();
    debug_close();
}

- (void)networkRunning {
    if (_bRunning) {
        mnet_check(0, 1);
        [self performSelector:@selector(networkRunning) withObject:nil afterDelay:0.05];
    }
}

- (void)httpServCb:(client_http_serv_state_t*)st {
    if (st->method == HTTP_METHOD_GET) {
        return;
    }
    
    if (st->state == HTTP_CB_STATE_BEGIN) {
        char fname[MDIR_MAX_PATH] = {0};
        char path[MDIR_MAX_PATH] = {0};
        strncpy(fname, st->path, st->path_len);
        sprintf(path, "%s/%s", _dataPath, fname);
        
        _fp = fopen(path, "wb");
        if (_fp == NULL) {
            NSLog(@"HTTP POST: Fail to open '%s'", path);
        }
        else {
            CGSize vsize = self.view.frame.size;
            CGRect r = CGRectMake(35, vsize.height/2-30, vsize.width-70, 100);
            UIView *pView = [[UIView alloc] initWithFrame:r];
            pView.backgroundColor = [UIColor lightGrayColor];
            pView.layer.borderColor = [UIColor lightGrayColor].CGColor;
            pView.layer.borderWidth = .5;
            pView.layer.cornerRadius = 5.;
            pView.layer.masksToBounds = YES;
            [self.view addSubview:pView];

            r = CGRectMake(15,30,r.size.width-30,30);
            UILabel *lb = [[UILabel alloc] initWithFrame:r];
            lb.textColor = [UIColor blackColor];
            lb.textAlignment = NSTextAlignmentCenter;
            lb.text = [NSString stringWithFormat:@"Upload file '%s'", fname];
            [pView addSubview:lb];
            
            int w = r.size.width;
            r = CGRectMake(15,80,1,10);
            UIView *v = [[UIView alloc] initWithFrame:r];
            v.backgroundColor = [UIColor blueColor];
            v.layer.borderColor = [UIColor lightGrayColor].CGColor;
            v.layer.borderWidth = .5;
            v.layer.cornerRadius = 5.;
            v.layer.masksToBounds = YES;
            v.tag = w;
            [pView addSubview:v];
            _progressView = v;
        }
    }
    else if (st->state == HTTP_CB_STATE_CONTINUE) {
        if (_fp) {
            int ret = (int)fwrite(st->buf, 1, st->buf_len, _fp);
            NSLog(@"HTTP POST: Write data length %d of %d", ret, st->buf_len);
            
            if (_progressView) {
            CGRect r = _progressView.frame;
            _progressView.frame = (CGRect){r.origin,
                _progressView.tag*st->bytes_consumed/(double)st->total_length, r.size.height};
            }
        }
    }
    else if (st->state == HTTP_CB_STATE_END) {
        if (_fp) {
            fclose(_fp);
            _fp = NULL;
            NSLog(@"HTTP POST: Data stream end, clsoe file");
            
            if(_progressView) {
                CGRect r = _progressView.frame;
                _progressView.frame = (CGRect){r.origin, _progressView.tag, r.size.height};
                
                dispatch_time_t tm = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC));
                dispatch_after(tm, dispatch_get_main_queue(), ^{
                    [UIView animateWithDuration:3 animations:^{
                        _progressView.superview.alpha = 0;
                    } completion:^(BOOL finished){
                        [_progressView.superview removeFromSuperview];
                    }];
                });
            }
        }
        
        [self reloadLocalData];
    }
}

#pragma mark - Local Data Manipulation

- (void)reloadLocalData {
    mdir_t *md = mdir_open(_dataPath);
    if (md) {
        lst_t *lst = mdir_list(md, 1024);
        if (lst) {
            [_fileNameAry removeAllObjects];
            char path[MDIR_MAX_PATH] = {0};
            
            for (int i=0; i<lst_count(lst); i++) {
                mdir_entry_t *e = lst_popf(lst);
                if (strcmp(e->name, "..") != 0) {   // skip parent dir
                    strncpy(path, e->name, e->namlen);
                    path[e->namlen] = 0;
                    NSString *str = [[NSString alloc] initWithCString:path encoding:NSUTF8StringEncoding];
                    [_fileNameAry addObject:[NSString stringWithFormat:@"   %@  (%.2f M)", str, e->fsize/(float)(1<<20)]];
                }
                lst_pushl(lst, e);
            }
        }
        mdir_close(md);
        [_tblView reloadData];
    }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _fileNameAry.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 100;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_bRunning) {
        return [NSString stringWithFormat:@" http://%s:1234", _ipAddr];
    }
    return @"\tFail to running, please check your network !";
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TblCell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"TblCell"];
    }
    cell.textLabel.text = _fileNameAry[indexPath.row];
    return cell;
}


@end
