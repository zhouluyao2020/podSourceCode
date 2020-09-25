//
//  LTM3U8Downloader.m
//  LTM3U8Downloader
//
//  Created by 刘涛 on 2019/5/29.
//  Copyright © 2019 刘涛. All rights reserved.
//

#import "ZGM3U8Downloader.h"
#import <AFNetworking/AFNetworking.h>
#import <M3U8Kit/M3U8Parser.h>
#import <pthread.h>
#import "ZGDownloadManager.h"
#import "ZGCachableFile.h"

NSString *const LTShouldReDwonloadNotification = @"LTShouldReDwonloadNotification";

#define LTResumeDataFolderPath [NSHomeDirectory() stringByAppendingString:@"/Documents/DownloadFiles/ResumeData"]


@interface ZGM3U8Downloader()

@property (nonatomic, assign) BOOL hasSuspendTasks; //是否暂停了任务

@property (nonatomic, strong) NSOperationQueue *downloadTasksAssembleQueue;

@property (nonatomic, strong) dispatch_semaphore_t downloadTaskSemephore;

@property (nonatomic, strong) NSMutableDictionary *tasksDic;

@property (nonatomic, assign) NSUInteger finishedSegmentVideoCount;

@property (nonatomic, assign) NSUInteger completeUnitCount_recentDownloadTotal; //最新下载的字节数

@property (nonatomic, assign) NSUInteger failedCount;//片段下载失败的次数（超过3次就直接报错）

@property (nonatomic, assign) BOOL shouldReDownload;   //是否要重新下载

@property (nonatomic, assign) NSUInteger totalSegmentsCount;    //视频片段总大小

@property (nonatomic, strong) AFNetworkReachabilityManager *myAFNetworkReachabilityManager;

@property (nonatomic, strong) NSMutableArray <NSURL *>* segmentURLs;   //下载切片的URL
@property (nonatomic, strong) NSString *keyUrlString;                  //文件秘钥

@end

@implementation ZGM3U8Downloader

- (instancetype)init{
    if (self = [super init]) {
        self.downloadTasksAssembleQueue = [[NSOperationQueue alloc] init];
        self.downloadTasksAssembleQueue.maxConcurrentOperationCount = 6;
        
        if (!_downloadTaskSemephore) {
            _downloadTaskSemephore = dispatch_semaphore_create(6);
        }
        
        self.tasksDic = [NSMutableDictionary dictionary];
        
        self.completeUnitCount_recentDownloadTotal = 0;
    }
    return self;
}

- (CGFloat)currentDownloadSpeed {
    CGFloat speed = self.completeUnitCount_recentDownloadTotal/1024/2;
    self.completeUnitCount_recentDownloadTotal = 0;
    return speed;
}

- (void)download:(ZGCachableFile *)file{
    //创建存储文件夹
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:file.cachedFolderPath]) {
        NSError *error;
        BOOL createFoldSuccess = [fileManager createDirectoryAtPath:file.cachedFolderPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (!createFoldSuccess) {
            NSLog(@"ddd");
        }
    }
    
    //1.获取 m3u8 文件（先检查本地是否已经下载该文件，如果没有，从远程获取该文件）
    NSString *targetPath = [NSString stringWithFormat:@"%@/%@.m3u8",file.cachedFolderPath,file.fileID];
    NSURL *m3u8FileURL;
    if ([fileManager fileExistsAtPath:targetPath]) {
        m3u8FileURL = [NSURL fileURLWithPath:targetPath];
    } else {//从服务器下载
        [self downloadM3U8FileFromServerWithURLSring:file.fileURL savedTo:targetPath];
        m3u8FileURL = [NSURL URLWithString:file.fileURL];
    }
    
    //解析m3u8 文件,并创建下载任务
    __weak typeof(file) weakFile = file;
    [self parseM3U8FilesFromUrl:m3u8FileURL saveSegmentFilesTo:file.cachedFolderPath handleDownloadProgress:^(CGFloat progress) {
        if (!weakFile) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            weakFile.downloadProgress = progress;
            
            if (![[ZGDownloadManager sharedManager].allManagedFiles containsObject:weakFile]) {
                NSLog(@"LTVideoDownload---注意，仍然在处理已移除的model");
            }
            if (progress >= 1.0) {
                NSLog(@"LTVideoDownload---全部下载完成");
                //                weakFile.downloadStatus = ZGCacheStatus_finished;
                //                [ZGCacheDataBase updateDownloadFile:weakFile];
                //发送通知，自动开始下一个等待中的视频的下载
                [[NSNotificationCenter defaultCenter] postNotificationName:ZGCacheShouldDownloadNextWaitingFileNotification object:nil];
                //对m3u8重写处理，视频片段路径由网络地址改为同济目录下的文件
                [self rewirteM3u8FileAtPath:targetPath];
            }
        });
        
    } startDownload:^(BOOL success) {
        if (!success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                weakFile.downloadStatus = ZGCacheStatus_failed;
            });
        }
    }];
}

#pragma mark -从远程下载 M3U8 文件
- (void)downloadM3U8FileFromServerWithURLSring:(NSString *)urlString savedTo:(NSString *)targetPath{
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    NSURL *targetURL = [NSURL fileURLWithPath:targetPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:targetPath]) {
        NSURLSessionDownloadTask *task =  [ZGDownloader.sessionManager downloadTaskWithRequest:request progress:nil destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            NSLog(@"LTVideoDownload---****************************\ndestination targetPath:%@ \nresponse:%@",targetPath.absoluteString,response);
            return targetURL;
        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
            if (error) {
                NSLog(@"LTVideoDownload---****************************\nerror:%@",error.localizedDescription);
            } else {
                NSLog(@"LTVideoDownload---m3u8 文件下载完成");
            }
        }];
        [task resume];
    } else {
        NSLog(@"LTVideoDownload---m3u8 文件已存在");
    }
}

#pragma mark -下载key文件
- (void)downloadKeyFileFromServerWithURLSring:(NSString *)urlString savedTo:(NSString *)targetPath{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    NSURLSessionDownloadTask *downloadTask = [ZGDownloader.sessionManager downloadTaskWithRequest:request progress:nil destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        return [NSURL fileURLWithPath:targetPath];
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        NSUInteger keySize = [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@",[filePath path]]];
        NSLog(@"%lu",(unsigned long)keySize);
        if (keySize == 16) {
            NSLog(@"key下载成功");
        }else {
            [[NSNotificationCenter defaultCenter]postNotificationName:@"keyDownloadFail" object:nil];
        }
        NSLog(@"下载完成3");
        
        if (error) {
            NSLog(@"key下载失败");
        }
    }];
    //启动下载任务
    [downloadTask resume];
    
//    [self.keyUrlDataArray enumerateObjectsUsingBlock:^(id obj,NSUInteger idx,BOOL *stop){
//
//
//    }];
}


#pragma mark -解析 m3u8 文件，根据解析后的下载地址创建下载任务
- (void)parseM3U8FilesFromUrl:(NSURL *)url saveSegmentFilesTo:(NSString *)folderPath handleDownloadProgress:(void(^)(CGFloat progress))proceedTo startDownload:(void(^)(BOOL success))startDownload{
    typeof(self) weakSelf = self;
    [url loadM3U8AsyncCompletion:^(M3U8PlaylistModel *model, NSError *error) {
        if (error) {
            NSLog(@"LTVideoDownload---error:%@",error);
            startDownload(false);
            return;
        }
        
        startDownload(true);
        
        //处理key文件
        if (model.mainMediaPl.segmentList.count > 0) {
            __block pthread_mutex_t mutex;
            pthread_mutex_init(&mutex, NULL);
            
            self.finishedSegmentVideoCount = 0;
            //获取已下载的文件总数
            NSDirectoryEnumerator *enumator = [[NSFileManager defaultManager] enumeratorAtPath:folderPath];
            for (NSString *subFilePah in enumator.allObjects) {
                if ([subFilePah hasSuffix:@".zg"]) {
                    weakSelf.finishedSegmentVideoCount++;
                } else {
                    
                }
            }
            proceedTo(weakSelf.finishedSegmentVideoCount * 1.0 / model.mainMediaPl.segmentList.count);
            
            
            if (weakSelf.finishedSegmentVideoCount == model.mainMediaPl.segmentList.count) {
                return;//已经全部下载完成，直接返回
            }
            
            //遍历 m3u8 文件的列表，如果列表中的文件未下载，则创建 NSURlSessionTask 并开始下载
            CFTimeInterval start = CACurrentMediaTime();
            
            self.segmentURLs = [NSMutableArray array];
            self.totalSegmentsCount = model.mainMediaPl.segmentList.count;
            for (int i=0;i<model.mainMediaPl.segmentList.count;i++) {
                M3U8SegmentInfo *segmantInfo = [model.mainMediaPl.segmentList segmentInfoAtIndex:i];
                NSURL *URI = segmantInfo.URI;
                
                NSString *fileNameStr = URI.absoluteString.lastPathComponent;
                NSString *targetPath = [folderPath stringByAppendingPathComponent:fileNameStr];
                BOOL fileHasBeenDownloaded = [[NSFileManager defaultManager] fileExistsAtPath:targetPath];
                if (fileHasBeenDownloaded) {
                    continue;
                }
                if ([URI.absoluteString hasSuffix:@".zg"]) {
                    [self.segmentURLs addObject:segmantInfo.URI];
                } else if ([URI.absoluteString hasPrefix:@"ppt-"]) {
                    NSString *pptUrl = [URI.absoluteString stringByReplacingOccurrencesOfString:@"ppt-" withString:@""];
                    [self.segmentURLs addObject:[NSURL URLWithString:pptUrl]];
                } else {
                    self.keyUrlString = URI.absoluteString;
                }
                
            }
            
            
            [self.downloadTasksAssembleQueue addOperationWithBlock:^{
                while (self.segmentURLs.count > 0) {
                    if (!self.hasSuspendTasks) {
                        NSURL *url = self.segmentURLs.firstObject;
                        [self.segmentURLs removeObjectAtIndex:0];
                        [self downloadWithURI:url saveTo:[NSString stringWithFormat:@"%@/%@",folderPath,url.absoluteString.lastPathComponent] progress:proceedTo];
                    }
                }
            }];
            
            //下载key
//            NSString *key = self.;
//            NSString *keyFilePath = [folderPath stringByAppendingPathComponent:@"0.key"];
//            [self downloadKeyFileFromServerWithURLSring:self.keyUrlString savedTo:keyFilePath];
            // dosomething
            CFTimeInterval end = CACurrentMediaTime();
            NSLog(@"LTVideoDownload---时间损耗 = %f s", end - start);
        }
    }];
}

#pragma mark -创建下载任务，下载分片视频文件
- (void)downloadWithURI:(NSURL *)URI saveTo:(NSString *)path progress:(void(^)(CGFloat progress))proceedTo{
    
    dispatch_semaphore_wait(self.downloadTaskSemephore, DISPATCH_TIME_FOREVER);
    
    NSURL *requestUrl = URI;
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:requestUrl];
    
    __block NSUInteger taskCompleteUnitCountLastRecord = 0;
    
    __weak typeof(self) weakSelf = self;
    __block NSURLSessionDownloadTask *task = [ZGDownloader.sessionManager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        
        if (task.state == NSURLSessionTaskStateRunning) {
            weakSelf.completeUnitCount_recentDownloadTotal += downloadProgress.completedUnitCount - taskCompleteUnitCountLastRecord;
            taskCompleteUnitCountLastRecord = downloadProgress.completedUnitCount;
        } else {
            NSLog(@"WTF!，task的state 不为 NSURLSessionTaskStateRunning");
        }
        
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        return [NSURL fileURLWithPath:path];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        dispatch_semaphore_signal(self.downloadTaskSemephore);
        
        if (error) {
            //            [weakSelf.tasksDic[URI] cancel];
            //            [weakSelf.tasksDic removeObjectForKey:URI];
            //            if (weakSelf.tasksDic.count == 0) {
            //                [self downloadFailedWithError:error];
            //            }
            
            if (weakSelf.failedCount >= 3) {
                [self cancelDownload];
                [self downloadFailedWithError:error];
            } else {
                NSLog(@"wtf!下载出错，uri：%@\npath:%@\nerror:%@", URI, path,error);
//                [task cancel];
//                [self.tasksDic removeObjectForKey:URI];
//                [self handleFailedTasksWithError:error url:URI saveTo:path progress:proceedTo];
            }
        } else {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                //                if ([self.segmentURLs containsObject:URI]) {
                ////                    [self.segmentURLs removeObject:URI];
                //                } else {
                //                    NSLog(@"WTF!");
                //                }
                [weakSelf.tasksDic removeObjectForKey:URI];
                weakSelf.finishedSegmentVideoCount += 1;
                
                
//                NSLog(@"LTVideoDownload---task:%@ finishedCount:%zi  totalCount:%zi",path,weakSelf.finishedSegmentVideoCount, totalCount);
                proceedTo(weakSelf.finishedSegmentVideoCount * 1.0 / self.totalSegmentsCount);
                
                if (weakSelf.finishedSegmentVideoCount == self.totalSegmentsCount) {
                    //完成全部下载，取消session
                    [self.downloadTasksAssembleQueue cancelAllOperations];
                    //                    [LTDownloader.sessionManager invalidateSessionCancelingTasks:YES];
                }
            });
        }
    }];
    
    dispatch_async(dispatch_get_main_queue(), ^{//进入主线程处理 resume（否则有可能在住线程暂停了下载，而子线程仍继续下载）
        self.tasksDic[URI] = task;
        if (!self.hasSuspendTasks) {
            //如果当前model 未处于suspend 状态，则 resume
            [task resume];
        } else {
            dispatch_semaphore_signal(self.downloadTaskSemephore);
        }
    });
    
}

- (void)handleFailedTasksWithError:(NSError *)error url:(NSURL *)url saveTo:(NSString *)path progress:(void(^)(CGFloat progress))proceedTo{
    //需要移除出错的文件？
    if (error.code == -999) {//取消了下载
        return;
    } else if(error.code == 2){
        //系统移除了临时文件，此时会报 Error Domain=NSPOSIXErrorDomain Code=2 "No such file or directory" 该错误在直接点击 xcode 的停止调试按钮后会出现，找不到解决办法
        if (self.shouldReDownload) {
            return;
        }
        NSLog(@"LTVideoDownload---出现了 No such file or directory 错误");
        [self cancelDownload];
        [[NSNotificationCenter defaultCenter] postNotificationName:LTShouldReDwonloadNotification object:self.downloadFileID];
        self.shouldReDownload = YES;
    } else {
        /*
         1.errorCode -1005 The network connection was lost.
        */
        //无网络，或者使用的是手机网络但用户只允许在 wifi 状态下下载
        if (self.hasSuspendTasks) {
            return;
        }
        
        BOOL isNetworkAllowDownload = ZGDownloadManager.sharedManager.allowDownloadViaWWAN || [AFNetworkReachabilityManager sharedManager].networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi;
        if (!isNetworkAllowDownload) {//网络恢复后继续下载
            __weak typeof(self) weakSelf = self;
            [self.myAFNetworkReachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
                if (ZGDownloadManager.sharedManager.allowDownloadViaWWAN || status == AFNetworkReachabilityStatusReachableViaWiFi) {
                    [weakSelf.segmentURLs enumerateObjectsUsingBlock:^(NSURL * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        [weakSelf.downloadTasksAssembleQueue addOperationWithBlock:^{
                            [weakSelf downloadWithURI:url saveTo:path progress:proceedTo];
                        }];
                    }];
                }
            }];

            [[AFNetworkReachabilityManager sharedManager] startMonitoring];

        } else {
            [self downloadWithURI:url saveTo:path progress:proceedTo];
        }
    }
}

- (AFNetworkReachabilityManager *)myAFNetworkReachabilityManager{
    if (!_myAFNetworkReachabilityManager) {
        _myAFNetworkReachabilityManager = [AFNetworkReachabilityManager manager];
    }
    return _myAFNetworkReachabilityManager;
}

#pragma mark -暂停下载
- (void)suspendDownload{
    @synchronized (self) {
        for (NSString *taskKey in [self.tasksDic allKeys]) {
            NSURLSessionDownloadTask *task;
            task = self.tasksDic[taskKey];
            if (task.state == NSURLSessionTaskStateCompleted) {
                NSLog(@"LTVideoDownload---抓到一个completed 的task");
            }
            [task suspend];
        }
    };
    
    self.hasSuspendTasks = YES;
    self.completeUnitCount_recentDownloadTotal = 0;
}

#pragma mark -取消下载
- (void)cancelDownload{
    //    //取消创建下载任务队列
    //    [self.downloadTasksAssembleQueue cancelAllOperations];
    //    //取消session
    //    [LTDownloader.sessionManager invalidateSessionCancelingTasks:YES];
    
    
    @synchronized (self) {
        for (NSString *taskKey in [self.tasksDic allKeys]) {
            NSURLSessionDownloadTask *task = self.tasksDic[taskKey];
            [task cancel];
        }
        self.hasSuspendTasks = YES;
    }
}

#pragma mark -开始（继续）下载
- (void)resumeDownload{
    @synchronized (self) {
        if (self.tasksDic.allKeys.count == 0) {
            NSLog(@"WTF，tasksDic.allKeys总数为0");
        }
        for (NSString *taskKey in [self.tasksDic allKeys]) {
            NSURLSessionDownloadTask *task;
            task = self.tasksDic[taskKey];
            if(task.state == NSURLSessionTaskStateSuspended) {
                //有时候 suspend 的任务 resume 后没有任何反应，视频下载不下来了，待排查
                [task resume];
            } else if(task.state == NSURLSessionTaskStateCompleted) {
                [self.tasksDic removeObjectForKey:taskKey];
            } else {
                NSLog(@"LTVideoDownload---dd");
            }
        }
    };
    
    self.hasSuspendTasks = NO;
    
    //    dispatch_resume(self.downloadSpeedCaculateTimer);
}

- (void)dealloc{
    NSLog(@"LTVideoDownload---downloader 销毁了");
}

#pragma mark -存储resumeData
- (void)saveResumeData:(NSData *)resumeData{
    if (![[NSFileManager defaultManager] fileExistsAtPath:LTResumeDataFolderPath]) {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:LTResumeDataFolderPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"WTF!，创建resumeData存储路径出错");
            return;
        }
    }
    
    NSString *resumeDataFilePath = [NSString stringWithFormat:@"%@/%@_resume.txt", LTResumeDataFolderPath, self.downloadFileID];
    
    [[NSFileManager defaultManager] createFileAtPath:resumeDataFilePath contents:resumeData attributes:nil];
}

#pragma mark -重写m3u8file(远程路径改为本地路径、秘钥改为指向本地存储的key文件)
-(void)rewirteM3u8FileAtPath:(NSString *)path{
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return;
    }
    
    NSMutableArray * mutArray =[[NSMutableArray alloc]init];
    [mutArray removeAllObjects];
    
    NSMutableString * string = [[NSMutableString alloc]initWithString:[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]];
    NSArray *array= [string componentsSeparatedByString:@"\n"];
    
    NSInteger i =0;
    for (NSString * string2 in array){
        if([string2 hasPrefix:@"http://"]){
            NSString * fileString =[string2 lastPathComponent];
            NSRange  range = [string2 rangeOfString:fileString];
            NSMutableString * removeString =[NSMutableString stringWithString:string2];
            [removeString deleteCharactersInRange:range];
            
            NSMutableString * str  = [NSMutableString stringWithString:string2];
            [str deleteCharactersInRange:[str rangeOfString:removeString]];
            NSLog(@"str=%@",str);
            [mutArray addObject:str];
        }
        else if([string2 hasPrefix:@"#EXT-X-KEY"]){
            NSMutableString * string3 =[NSMutableString stringWithString:string2];
            NSRange range1 = [string3 rangeOfString:@"URI="];
            unsigned long location1 = range1.location+5;
            
            NSRange range2 = [string3 rangeOfString:@"IV="];
            unsigned long location2 = range2.location-2;
            
            NSRange rang = NSMakeRange(location1, location2-location1);
            NSString *str = [string3 stringByReplacingCharactersInRange:rang withString:[NSString stringWithFormat:@"%ld.key",i]];
            [mutArray addObject:str];
            i++;
        }
        else{
            [mutArray addObject:string2];
        }
    }
    NSString * str = [mutArray componentsJoinedByString:@"\n"];
    [str writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

@end
