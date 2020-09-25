//
//  LTVideoDownloader.m
//  LTVideoDownloadDemo
//
//  Created by 刘涛 on 2019/5/29.
//  Copyright © 2019 刘涛. All rights reserved.
//

#import "ZGDownloader.h"
#import "ZGGeneralDownloader.h"
#import "ZGM3U8Downloader.h"
#import "ZGDownloadManager.h"

NSString * const LTBackgroundDownloadSessionID = @"com.ltDownloadDemo.backgroundDownloadSession";

static AFHTTPSessionManager *sessionManager;

@interface ZGDownloader()

@end

@implementation ZGDownloader

+ (AFHTTPSessionManager *)sessionManager{
    return sessionManager;
}

- (instancetype)init{
    if ([self isMemberOfClass:[ZGDownloader class]]) {
        NSAssert(YES, @"这是一个抽象类，请使用initWithDownloadFileID:方法创建子类");
        return nil;
    } else {
        if (self == [super init]) {
            
        }
        return self;
    }
}

+ (instancetype)downloaderWithDownloadFileID:(NSString *)fileID isM3U8File:(BOOL)isM3U8File{
    NSAssert(fileID.length > 0, @"文件id为空");
    ZGDownloader *downloader;
    if (isM3U8File) {
        downloader = [[ZGM3U8Downloader alloc] init];
    } else {
        downloader = [[ZGGeneralDownloader alloc] init];
    }
    
    downloader->_downloadFileID = fileID;
    
    if (!sessionManager) {
        if (![ZGDownloadManager sharedManager].allowDownloadInBackGround) {
            sessionManager = [AFHTTPSessionManager manager];
        } else {
            //使用后台下载
//            NSString *configID = LTBackgroundDownloadSessionID;
//            NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:configID];
//            sessionManager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:configuration];
//            
//            [sessionManager setDidFinishEventsForBackgroundURLSessionBlock:^(NSURLSession * _Nonnull session) {
//                NSLog(@"LTVideoDownload---session 调用了completionHandler 但不知道执行了什么");
//                [sessionManager setDidFinishEventsForBackgroundURLSessionBlock:nil];
//            }];
            sessionManager = [AFHTTPSessionManager manager];
        }
    }
    
    return downloader;
}

+ (void)handleBackgroundDownloadDidFinishEvent{
    
}

- (CGFloat)downloadSpeed {
    return .0;
}

- (void)download:(ZGCachableFile *)file{
}

- (void)downloadFailedWithError:(NSError *)error{
    ZGCachableFile *file = [[ZGDownloadManager sharedManager] managedFileOfID:self.downloadFileID];
    [NSObject observersOfFile:file shouldDisposeError:error];
}

#pragma mark -暂停下载
- (void)suspendDownload{
}

#pragma mark -取消下载
- (void)cancelDownload{
}

#pragma mark -开始（继续）下载
- (void)resumeDownload{
}

- (void)dealloc{
    NSLog(@"LTVideoDownload---downloader 销毁了");
}

@end
