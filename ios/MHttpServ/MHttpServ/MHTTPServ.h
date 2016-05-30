//
//  Created by lalawue on 16/5/30.

#import <Foundation/Foundation.h>

@protocol MHTTPServDelegate <NSObject>
@optional
- (void)onMHTTPServEvent:(NSString*)errorMsg fileName:(NSString*)fileName fileSize:(int64_t)fileSize percent:(float)percent;
@end

@interface MHTTPServ : NSObject

@property (nonatomic,weak) id<MHTTPServDelegate>    delegate;

@property (nonatomic) NSString                      *pageTitle;   // 32 bytes, set before start
@property (nonatomic) NSString                      *pageDevName; // 32 bytes, set before start

@property (nonatomic,readonly) NSString             *ipAddr; // get ip after start


+ (instancetype)sharedIns;

- (BOOL)startServ:(NSString*)dirPath onPort:(NSInteger)port;
- (void)stopServ;
- (void)enumerateDir:(NSString*)dirPath block:(BOOL(^)(NSString *fileName, BOOL isDir, int64_t fileSize))block;

@end
