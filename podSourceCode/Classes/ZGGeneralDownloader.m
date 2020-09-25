//
//  LTGeneralDownloader.m
//  LTVideoDownloadDemo
//
//  Created by 刘涛 on 2020/7/2.
//  Copyright © 2020 刘涛. All rights reserved.
//

#import "ZGGeneralDownloader.h"
#import <AFNetworking/AFNetworking.h>
//#import "NSURL+m3u8.h"
#import <pthread.h>
#import "NSObject+YYAddForKVO.h"
#import "ZGDownloadManager.h"
#import "LTDownloadHelper.h"

@interface ZGGeneralDownloader()

@property (nonatomic, assign) NSUInteger finishedSegmentVideoCount;

@property (nonatomic, assign) NSUInteger completeUnitCount_recentDownloadTotal; //最新下载的字节数

@property (nonatomic, strong) NSURLSessionDownloadTask *task;

@end

@implementation ZGGeneralDownloader

#pragma mark -下载普通文件
- (void)download:(ZGCachableFile *)file{
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:file.fileURL]];
    NSString *targetPath = [[file.cachedFolderPath stringByAppendingPathComponent:file.fileID] stringByAppendingPathExtension:file.fileFormat];
    //        return filePath;
    NSURL *targetURL = [NSURL fileURLWithPath:targetPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:file.cachedFolderPath]) {
        [fileManager createDirectoryAtPath:file.cachedFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    __block NSUInteger taskCompleteUnitCountLastRecord = 0;
    
    //如果有resumeData，直接继续下载
    NSData *resumeData = [LTDownloadHelper fetchResumeDataOfDownloadFileWithID:self.downloadFileID];
    
    __block NSURLSessionDownloadTask * task;
    
    //把两种创建downloadTask的方式共用的block抽出来
    //进度回调
    void (^progressBlock) (NSProgress *downloadProgress)  = ^ (NSProgress *downloadProgress) {
        self.completeUnitCount_recentDownloadTotal += downloadProgress.completedUnitCount - taskCompleteUnitCountLastRecord;
        taskCompleteUnitCountLastRecord = downloadProgress.completedUnitCount;
        CGFloat percent = downloadProgress.completedUnitCount * 1.0/downloadProgress.totalUnitCount;
        NSLog(@"下载中：%f",percent);
        dispatch_async(dispatch_get_main_queue(), ^{
            file.downloadProgress = percent;
        });
    };
    
    //本地路径回调
    NSURL * (^destinationBlock) (NSURL *targetPath, NSURLResponse *response) = ^(NSURL *targetPath, NSURLResponse *response){
        return targetURL;
    };
    
    //下载结束
    void (^completionHandler)(NSURLResponse *response, NSURL *filePath, NSError *error) = ^(NSURLResponse *response, NSURL *filePath, NSError *error) {
      if (error) {
          NSLog(@"LTVideoDownload---****************************\nerror:%@",error.localizedDescription);
          [self downloadFailedWithError:error];
      } else {
//          file.downloadStatus = ZGCacheStatus_finished;
//          [ZGCacheDataBase updateDownloadFile:file];
      }
    };
    
    if (resumeData.length > 0) {
        task = [ZGDownloader.sessionManager downloadTaskWithResumeData:resumeData progress:progressBlock destination:destinationBlock completionHandler:completionHandler];
    }else {
        task = [ZGDownloader.sessionManager downloadTaskWithRequest:request progress:progressBlock destination:destinationBlock completionHandler:completionHandler];
    }
    if (task == nil) {
        NSLog(@"WTF!，没有任务");
    }
    
    [task resume];
    
    self.task = task;
}

- (CGFloat)currentDownloadSpeed {
    CGFloat speed = self.completeUnitCount_recentDownloadTotal/1024/2;
    self.completeUnitCount_recentDownloadTotal = 0;
    return speed;
}

#pragma mark -暂停下载
- (void)suspendDownload{
    [self.task suspend];
    self.completeUnitCount_recentDownloadTotal = 0;
}

#pragma mark -取消下载
- (void)cancelDownload{
    //取消session
//    [LTDownloader.sessionManager invalidateSessionCancelingTasks:YES];
    [self.task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        [LTDownloadHelper saveResumeData:resumeData withFileID:self.downloadFileID];
    }];
}

#pragma mark -开始（继续）下载
- (void)resumeDownload{
    if(self.task.state == NSURLSessionTaskStateSuspended) {
        //有时候 suspend 的任务 resume 后没有任何反应，视频下载不下来了，待排查
        [self.task resume];
    } else {
        NSLog(@"LTVideoDownload---dd");
    }
}

- (void)dealloc{
    NSLog(@"LTVideoDownload---downloader 销毁了");
}



@end
