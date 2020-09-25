//
//  LTVideoDownloader.h
//  LTVideoDownloadDemo
//
//  Created by 刘涛 on 2019/5/29.
//  Copyright © 2019 刘涛. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>
#import "ZGCachableFile.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const LTBackgroundDownloadSessionID;

@interface ZGDownloader : NSObject

@property (nonatomic, copy, readonly) NSString *downloadFileID;

@property (class, readonly, nonatomic, strong) AFHTTPSessionManager *sessionManager;

+ (instancetype)downloaderWithDownloadFileID:(NSString *)fileID isM3U8File:(BOOL)isM3U8File;

- (void)resumeDownload;

- (void)suspendDownload;

- (void)cancelDownload;



#pragma mark -下载文件
- (void)download:(ZGCachableFile *)file;

- (CGFloat)currentDownloadSpeed; //下载速率 KB/s

- (void)downloadFailedWithError:(NSError *)error;

+ (void)handleBackgroundDownloadDidFinishEvent;

@end

NS_ASSUME_NONNULL_END
