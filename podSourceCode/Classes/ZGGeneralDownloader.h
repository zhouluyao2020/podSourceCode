//
//  LTGeneralDownloader.h
//  LTVideoDownloadDemo
//
//  Created by 刘涛 on 2020/7/2.
//  Copyright © 2020 刘涛. All rights reserved.
//

#import "ZGDownloader.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZGGeneralDownloader : ZGDownloader

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
