//
//  Created by lalawue on 16/5/30.

#import "MHTTPServ.h"

#import "m_debug.h"
#import "plat_net.h"
#import "client_http_serv.h"

#include <ifaddrs.h>
#include <arpa/inet.h>

@implementation MHTTPServ {
    NSString            *_ipAddr, *_fileName;
    int64_t             _fileSize;
    BOOL                _isNetworkRunning;
    char                _dirPath[MDIR_MAX_PATH];
    FILE                *_fp;
}

+ (instancetype)sharedIns {
    static MHTTPServ *serv;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        serv = [[MHTTPServ alloc] init];
    });
    return serv;
}

- (id)init {
    self = [super init];
    return self;
}

- (NSString*)ipAddr {
    if (_isNetworkRunning) {
        return _ipAddr;
    }
    return nil;
}

- (void)setDelegate:(id<MHTTPServDelegate>)delegate {
    if (delegate && [delegate respondsToSelector:@selector(onMHTTPServEvent:fileName:fileSize:percent:)]) {
        _delegate = delegate;
    }
    else {
        _delegate = nil;
    }
}

// from 'http://zachwaugh.me/posts/programmatically-retrieving-ip-address-of-iphone/'
- (NSString *)getIPAddress
{
    NSString *address = nil;
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
    [[MHTTPServ sharedIns] httpServCB:st];
}

- (void)runningNetwork {
    if (_isNetworkRunning) {
        mnet_check(0);
        [self performSelector:@selector(runningNetwork) withObject:nil afterDelay:0.01];
    }
}

- (BOOL)startServ:(NSString *)dirPath onPort:(NSInteger)port {
    
    if (dirPath.length<=0 || port<=1024) {
        if (_delegate) {
            [_delegate onMHTTPServEvent:@"param error" fileName:nil fileSize:0 percent:0];
        }
        return NO;
    }
    
    _ipAddr = [self getIPAddress];
    if (_ipAddr == nil) {
        if (_delegate && [_delegate respondsToSelector:@selector(onMHTTPServEvent:fileName:fileSize:percent:)]) {
            [_delegate onMHTTPServEvent:@"fail to get ip addr" fileName:nil fileSize:0 percent:0];
        }
        return NO;
    }


    // int network
    debug_open("stdout");
    if (mnet_init() <= 0) {
        if (_delegate) {
            [_delegate onMHTTPServEvent:@"fail to init network" fileName:nil fileSize:0 percent:0];
        }
        return NO;
    }
    
    
    // set serv config
    client_http_serv_config_t conf;
    memset(&conf, 0, sizeof(conf));
    
    conf.port = (int)port;
    conf.opaque = NULL;
    
    if (_pageTitle.length>0 && _pageTitle.length<32) {
        [_pageTitle getCString:conf.title maxLength:32 encoding:NSUTF8StringEncoding];
    } else {
        strcpy(conf.title, "Welcome to MHttpServ");
    }
    
    if (_pageDevName.length>0 && _pageDevName.length<32) {
        [_pageDevName getCString:conf.dev_name maxLength:32 encoding:NSUTF8StringEncoding];
    }
    else {
        strcpy(conf.dev_name, "Nobody's iOS Device");
    }
    
    [_ipAddr getCString:conf.ipaddr maxLength:sizeof(conf.ipaddr) encoding:NSUTF8StringEncoding];
    [dirPath getCString:conf.dpath maxLength:MDIR_MAX_PATH encoding:NSUTF8StringEncoding];
    memcpy(_dirPath, conf.dpath, MDIR_MAX_PATH);
    
    if (client_http_serv_open(&conf, _http_serv_cb)) {
        _isNetworkRunning = YES;
        [self runningNetwork];
        return YES;
    }
    
    return NO;
}

- (void)stopServ {
    _isNetworkRunning = NO;
    client_http_serv_close();
    mnet_fini();
    debug_close();
}

- (void)httpServCB:(client_http_serv_state_t*)st {
    if (st->method == HTTP_METHOD_GET) {
        return;
    }

    NSString *errMsg = nil;
    
    if (st->state == HTTP_CB_STATE_BEGIN) {
        char fname[MDIR_MAX_PATH] = {0};
        char path[MDIR_MAX_PATH] = {0};
        
        strncpy(fname, st->fname, st->fname_len);
        sprintf(path, "%s/%s", _dirPath, fname);
        
        _fileName = [NSString stringWithUTF8String:fname];
        _fileSize = st->total_length;
        
        _fp = fopen(path, "wb");
        if (_delegate) {
            if (_fp == NULL) {
                errMsg = @"fail to create file" ;
            }
            [_delegate onMHTTPServEvent:errMsg fileName:_fileName fileSize:_fileSize percent:0];
        }
    }
    else if (st->state == HTTP_CB_STATE_CONTINUE) {
        if (_fp) {
            int ret = (int)fwrite(st->buf, 1, st->buf_len, _fp);
            NSLog(@"HTTP POST: Write data length %d of %d", ret, st->buf_len);

            if (ret < 0) {
                fclose(_fp);
                _fp = NULL;
                errMsg = @"http serv fail to write";
            }
            
            if (_delegate) {
                float percent = (float)st->bytes_consumed / (float)st->total_length;
                [_delegate onMHTTPServEvent:errMsg fileName:_fileName fileSize:_fileSize percent:percent];
            }
        }
    }
    else if (st->state == HTTP_CB_STATE_END) {
        if (_fp) {
            fclose(_fp);
            _fp = NULL;
            NSLog(@"HTTP POST: Data stream end, clsoe file");
            
            if(_delegate) {
                [_delegate onMHTTPServEvent:nil fileName:_fileName fileSize:_fileSize percent:1.];
            }
        }
    }
    else if (st->state == HTTP_CB_STATE_ERROR) {
        if (_fp) {
            fclose(_fp);
            _fp = NULL;
            NSLog(@"HTTP POST: Data abort uploading");
            
            if (_delegate) {
                float percent = (float)st->bytes_consumed / (float)st->total_length;
                [_delegate onMHTTPServEvent:@"http server error" fileName:_fileName fileSize:_fileSize percent:percent];
            }
        }
    }
}

/// return false to stop in block
- (void)enumerateDir:(NSString *)dirPath block:(BOOL (^)(NSString *, BOOL, int64_t))block {
    if (dirPath.length>0 && block) {
        char path[MDIR_MAX_PATH] = {0};
        [dirPath getCString:path maxLength:MDIR_MAX_PATH encoding:NSUTF8StringEncoding];
        
        mdir_t *m = mdir_open(path);
        if (m) {
            lst_t* lst = mdir_list(m, 1024);
            if (lst) {
                lst_foreach(it, lst) {
                    mdir_entry_t *e = lst_iter_data(it);
                    NSString *fileName = [[NSString alloc] initWithBytes:e->name length:e->namlen encoding:NSUTF8StringEncoding];
                    if (block(fileName, (e->ftype & MDIR_DIRECOTRY), e->fsize) == NO) {
                        break;
                    }
                }
            }
        }
        mdir_close(m);
    }
}

@end
