
# About

Cross platform HTTP Server support browser download/upload files, 
include iOS/MacOSX/Linux/Windows demo.

And another demo using Lua to process HTTP protocol, only testing under
MacOSX.





# MacOSX demo

Just make, and provide computer's IP address, port and directory

```
# make
# ./out/http_serv.out 127.0.0.1 1234 data
```

Then open your browser and address 'http://127.0.0.1:1234' to visit.


Or, you need Lua installed under /usr/local (or using brew).

```
#./out/lua_serv.out 127.0.0.1 1234
```

Then open your browser and address

'http://127.0.0.1:1234/jstest/index.do?file=jstest_url.html'

to visit html page under ./data dir, more detail in src/lua/agent_jstest.lua.

or try download, upload by

```
curl http://127.0.0.1:1234/cdata/get_file.do?file=jstest_url.html
curl -X POST --data-binary @README.md  http://127.0.0.1:1234/cdata/post_file.do?file=upload.txt
```

more detail in src/lua/agent_cdata.lua.






# iOS demo

iOS demo was under ios directory, open the xcode project and run the example.

App Store example, https://itunes.apple.com/cn/app/sui-shen-pan/id1076334703

The ObjC interface of MHTTPServ was below:
````obj-c
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
```

It's a standalone serv, set delegate, pageTitle, pageDevName before startServ, then you can get ipAddr. stopServ to shutdown the networking, and before startServ from another dir.

When system's WIFI was off, startServ will fail, and no ipAddr available.

Any file POST will invoke delegate onMHTTPServEvent, errorMsg should be nil in normal, and percent indicates upload progress from 0 ~ 1.0.

enumerateDir to get the latest dir info list.

the real world example is HTTPServViewController.m.




# Linux Demo

Similar to the MacOSX, make and run, make sure the directory your can read/write.





# Windows demo

Windows demo was under win directory, open the .sln solution, set ipaddr, port,
 directory in argv input parameter, run the example, then open your browser to visit.





# Note

Files was filtered in plat_dir.c, internal UTF-8 charset.
