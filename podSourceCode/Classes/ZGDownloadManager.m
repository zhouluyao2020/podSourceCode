//
//  ZGDownloadManager.m
//  ZGStudentServicesHD
//
//  Created by 刘涛 on 2020/6/1.
//  Copyright © 2020 offcn. All rights reserved.
//

#import "ZGDownloadManager.h"
#import "ZGCacheDataBase.h"
#import "ZGDownloadManager.h"
#import "HCKeepBGRunManager.h"

NSString *const ZGCacheShouldDownloadNextWaitingFileNotification = @"ZGCacheShouldDownloadNextWaitingFileNotification";

NSString *const ZGCacheShouldUpdateDatasourceNotification = @"ZGCahceShouldUpdateDatasourceNotification";

@interface ZGDownloadManager(){
    NSString *_currentAccount;
}

@property (nonatomic, strong) NSMutableDictionary *downloadersDic;

@property (nonatomic, strong) dispatch_source_t downloadSpeedRefreshTimer; //下载速率刷新timer

@property (nonatomic, assign, getter=isSpeedTimerSuspended) BOOL speedTimerSuspended;   //timer是否暂停

@property (nonatomic, assign) BOOL isInBackgroundRunMode;//是否处于后台常驻状态

@end

@implementation ZGDownloadManager
@dynamic currentAccount;

+ (instancetype)sharedManager{
    static ZGDownloadManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!manager) {
            manager = [[ZGDownloadManager alloc] init];
            
            manager.downloadersDic = [NSMutableDictionary dictionary];
            
            manager.maxConcurrentDownloadVideosCount = 3;
            
            manager.allowDownloadInBackGround = YES;
            
            manager.allowDownloadViaWWAN = YES;
            
            [[NSNotificationCenter defaultCenter] addObserver:manager selector:@selector(downloadNextVideo) name:ZGCacheShouldDownloadNextWaitingFileNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:manager selector:@selector(updateDatabase) name:ZGCacheShouldUpdateDatasourceNotification object:nil];
            //            [[NSNotificationCenter defaultCenter] addObserver:manager selector:@selector(receivedRedownloadVideoNotification:) name:LTShouldReDwonloadNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:manager selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:manager selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        }
    });
    return manager;
}

- (void)bindWithAccount:(NSString *)account{
    if (![_currentAccount isEqualToString:account]) {
        _currentAccount = account;
    }
}

- (NSString *)currentAccount{
    return _currentAccount ?: @"游客";
}

#pragma mark:当前正在缓存文件数量
- (NSUInteger)totalCountOfInCachingFiles{
    __block NSUInteger count = 0;
    [self.allManagedFiles enumerateObjectsUsingBlock:^(ZGCachableFile * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.downloadStatus != ZGCacheStatus_finished) {
            count++;
        }
    }];
    return count;
}

#pragma mark:获取已经完成缓存的文件总数
- (NSUInteger)totalCountOfCachedFiles{
    __block NSUInteger count = 0;
    [[ZGDownloadManager sharedManager].allManagedFiles enumerateObjectsUsingBlock:^(ZGCachableFile * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.downloadStatus == ZGCacheStatus_finished) {
            count++;
        }
    }];
    return count;
}

#pragma mark:外部模块获取文件（视频、回放、资料）的下载状态
- (ZGCacheStatus)downloadStatusOfFileWhoseFileIDis:(NSString *)fileID
                                               fileType:(NSInteger)fileType{
    //数据库中非服务包文件，其服务包idn被设为@"000000"
    return [self managedFileOfID:fileID].downloadStatus;
}

/// 视频记录时长
/// @param fileID 文件id
+ (NSString *)recordedWatchTimeOfVideoWihtFileID:(NSString *)fileID{
//    NSUInteger seconds = [[ZGDatabaseOnDownload shareDataManager ] recordTimeOfFileWithFileID:fileID packageID:@"000000"];
//
//    return [NSString stringWithFormat:@"%lu",(unsigned long)seconds];
//    if (seconds == 0) {
//        return nil;
//    }
    //把秒数转成 HH:mm:ss 格式
//    NSString *durationStr = [NSString stringWithFormat:@"%02lu:%02u:%02u",seconds/360, (seconds%360)/60,seconds%60];
//    if ([durationStr hasPrefix:@"00:"]) {
//        durationStr = [durationStr substringFromIndex:3];
//    }
//    return durationStr;
    return nil;
}

//#pragma mark:将缓存文件存入一个队列
//+ (void)addFileToDeleteNotificationQueueWithDownloadFileName:(NSString *)downloadFileName downloadStatus:(ZGCacheStatus)downloadStatus {
//    //移除观察者
////    [ZGDownloadStatusObserver.observerMapTable removeObjectForKey:downloadFileName];
//    
//    if ([ZGMethod isEmpty:downloadFileName]) {
//        return;
//    }
//    
//    static NSMutableSet *deleteFiles;
//    if (!deleteFiles) {
//        deleteFiles = [NSMutableSet set];
//    }
//    NSDictionary *fileInfoDic = @{downloadFileName : @(downloadStatus)};
//    [deleteFiles addObject:fileInfoDic];
//    
//    if (deleteFiles.count == 1) {//1后发送通知（只有在count == 1时才执行，避免重复发送，发送成功后清除set）
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            [[NSNotificationCenter defaultCenter] postNotificationName:ZGCacheShouldUpdateDatasourceNotification object:deleteFiles];
//            @synchronized (self) {
//                //通知完后删除当前set里的所有元素
//                [deleteFiles removeAllObjects];
//            }
//        });
//    }
//}

- (void)download:(ZGCachableFile *)model{
    BOOL allowDownload = YES;
    AFNetworkReachabilityStatus reachabilityStatus = [AFNetworkReachabilityManager sharedManager].networkReachabilityStatus;
    if (!self.allowDownloadViaWWAN && (reachabilityStatus == AFNetworkReachabilityStatusReachableViaWWAN)) {
        allowDownload = NO;
    }
    if (allowDownload) {
        BOOL isM3U8File = (model.fileType == ZGCachableFileType_video || model.fileType == ZGCachableFileType_replay);
        [self download:model isM3U8File:isM3U8File];
    } else {
        NSLog(@"非wifi环境下不能下载");
    }
}

- (void)download:(ZGCachableFile *)model isM3U8File:(BOOL)isM3U8{
    ZGCachableFile *cachedModel = [self managedFileOfID:model.fileID];
    
    if (!cachedModel) {
        model.downloadStatus = ZGCacheStatus_willBegin;
        model.downloadProgress = 0.0;
        [[ZGDownloadManager sharedManager].allManagedFiles addObject:model];
        [ZGCacheDataBase insertDownloadFile:model];
        [[NSNotificationCenter defaultCenter] postNotificationName:ZGCacheShouldUpdateDatasourceNotification object:nil];
    } else {
        model = cachedModel;
    }
    
    //检查是否正在下载或已下载完成
    if (!model || model.downloadStatus == ZGCacheStatus_inDownloading || model.downloadStatus == ZGCacheStatus_finished) {
        return;
    }
    
    //检查是否超过最大同时下载个数
    int downloadingVideoCount = 0;
    for (ZGCachableFile *downloadVideoModel in self.allManagedFiles) {
        if (downloadVideoModel.downloadStatus == ZGCacheStatus_inDownloading) {
            downloadingVideoCount++;
            if (downloadingVideoCount >= self.maxConcurrentDownloadVideosCount) {
                model.downloadStatus = ZGCacheStatus_willBegin;
                return;
            }
        }
    }
    
    //
    model.downloadStatus = ZGCacheStatus_inDownloading;
    ZGDownloader *downLoader = self.downloadersDic[model.fileID];
    if (downLoader) {
        [downLoader resumeDownload];
    } else {
        //创建downloader
        ZGDownloader *downLoader = [ZGDownloader downloaderWithDownloadFileID:model.fileID isM3U8File:isM3U8];
        self.downloadersDic[model.fileID] = downLoader;
        [downLoader download:model];
        [self observeDownloadFileOfID:model.fileID withStatusCallback:^(ZGCacheStatus downloadStatus) {
            if (downloadStatus == ZGCacheStatus_finished) {
                dispatch_async(dispatch_get_main_queue(), ^{
                   [[NSNotificationCenter defaultCenter] postNotificationName:ZGCacheShouldUpdateDatasourceNotification object:nil];
                });
            }
        } progressCallback:nil speedCallback:nil handleError:nil];
    }
    if (!self.downloadSpeedRefreshTimer) {
        self.downloadSpeedRefreshTimer = [self createDownloadSpeedCaculateTimer];
        dispatch_resume(self.downloadSpeedRefreshTimer);
    }
    if (self.isSpeedTimerSuspended) {
        dispatch_resume(self.downloadSpeedRefreshTimer);
        self.speedTimerSuspended = NO;
    }
    
}

#pragma mark -下载速度计时器timer
- (dispatch_source_t)createDownloadSpeedCaculateTimer{
    dispatch_queue_t downloadSpeedCaculateQueue = dispatch_queue_create("downloadSpeedCaculateQueue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, downloadSpeedCaculateQueue);
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC, 0.001 * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(timer, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            for (ZGCachableFile *file in self.allManagedFiles) {
                if (file.downloadStatus == ZGCacheStatus_inDownloading) {
                    ZGDownloader *downloader = self.downloadersDic[file.fileID];
                    [NSObject observersOfFile:file shouldUpdateDownloadSpeed:[downloader currentDownloadSpeed]];
                    NSLog(@"LTVideoDownload---file:%@ progress:%f",file.cachedFolderPath,file.downloadProgress);
                }
                
            }
        });
    });
    
    return timer;
}

- (void)receivedRedownloadVideoNotification:(NSNotification *)notification{
    
    NSString *identifier = notification.object;
    for (ZGCachableFile *downloadVideoModel in self.allManagedFiles) {
        if ([downloadVideoModel.fileID isEqualToString:identifier]) {
            downloadVideoModel.downloadStatus = ZGCacheStatus_inDownloading;
            [self download:downloadVideoModel];
            return;
        }
    }
}

- (ZGCachableFile *)managedFileOfID:(NSString *)identifier{
    for (ZGCachableFile *videoModel in self.allManagedFiles) {
        if ([videoModel.fileID isEqualToString:identifier]) {
            return videoModel;
        }
    }
    return nil;
}

- (NSMutableArray *)allManagedFiles{
    if (!_allManagedFiles) {
        _allManagedFiles = [[ZGCacheDataBase allFilesInDatabase] mutableCopy];
    }
    return _allManagedFiles;
}

- (NSArray *)downloadingFiles{
    NSMutableArray *filesOnDownloading = [NSMutableArray array];
    [self.allManagedFiles enumerateObjectsUsingBlock:^(ZGCachableFile * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.downloadStatus == ZGCacheStatus_inDownloading) {
            [filesOnDownloading addObject:obj];
        }
    }];
    return filesOnDownloading;
}


- (void)suspend:(ZGCachableFile *)model{
    ZGDownloader *downloader = self.downloadersDic[model.fileID];
    [downloader suspendDownload];
    
    model.downloadStatus = ZGCacheStatus_suspend;
    if ([self downloadingFiles].count == 0) {
        if (self.downloadSpeedRefreshTimer && !self.isSpeedTimerSuspended) {
            dispatch_suspend(self.downloadSpeedRefreshTimer);
            self.speedTimerSuspended = YES;
        }
    }
    
}

- (void)remove:(ZGCachableFile *)downloadInfo{
    [self stopObserveDownloadFileOfID:downloadInfo.fileID];
    ZGCachableFile *managedDownloadInfo = [[ZGDownloadManager sharedManager] managedFileOfID:downloadInfo.fileID];
    
    [[[ZGDownloadManager sharedManager] allManagedFiles] removeObject:managedDownloadInfo];
    
    ZGDownloader *downloader = self.downloadersDic[downloadInfo.fileID];
    [downloader cancelDownload];
    [self.downloadersDic removeObjectForKey:downloadInfo.fileID];
    [[NSNotificationCenter defaultCenter] postNotificationName:ZGCacheShouldUpdateDatasourceNotification object:nil];
    
    //删除数据库中记录
    [ZGCacheDataBase removeDownloadFile:downloadInfo];
}


- (void)downloadNextVideo{
    //自动开始下载排等待队列中的第一个文件
    BOOL inDownloading = NO;
    for (ZGCachableFile *downloadVideoModel in self.allManagedFiles) {
        if (downloadVideoModel.downloadStatus == ZGCacheStatus_willBegin) {
            [self download:downloadVideoModel];
            return;
        }
        if (downloadVideoModel.downloadStatus == ZGCacheStatus_inDownloading) {
            inDownloading = YES;
        }
    }
    
    //没有等待中的下载任务，且当前没有正在下载的任务，此时检查是否应用处于后台常驻状态，如果是，则取消后台常驻状态
    if (self.isInBackgroundRunMode && !inDownloading) {
        [[HCKeepBGRunManager shareManager] stopBGRun];
        self.isInBackgroundRunMode = NO;
    }
}

#pragma mark -后台下载
//由于下载的视频是分片下载的，分片数量非常大，使用正常的backgroundconfiguration 实现后台下载会存在各种问题，详细见 https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_in_the_background?language=objc
#pragma mark -进入后台时，如果程序有正在下载的任务，通过播放一段无声音频实现进程常驻，保证后台继续下载
- (void)applicationDidEnterBackground:(NSNotification *)notification{
    //如果当前有正在下载的视频，则播放无声的音频，保证后台正常下载
    __block BOOL downloading = NO;
    [self.allManagedFiles enumerateObjectsUsingBlock:^(ZGCachableFile *  _Nonnull model, NSUInteger idx, BOOL * _Nonnull stop) {
        if (model.downloadStatus == ZGCacheStatus_inDownloading) {
            downloading = YES;
            *stop = YES;
        }
    }];
    
    if (downloading) {
        if (self.allowDownloadInBackGround) {
            [[HCKeepBGRunManager shareManager] startBGRun];
            self.isInBackgroundRunMode = YES;
        }
    }
    
    [self updateDatabase];
}

- (void)updateDatabase{
    for (ZGCachableFile *file in self.allManagedFiles) {
        [ZGCacheDataBase updateDownloadFile:file];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification{
    //如果当前正在播放无声的音频
    if (self.isInBackgroundRunMode) {
        [[HCKeepBGRunManager shareManager] stopBGRun];
        self.isInBackgroundRunMode = NO;
    }
}

@end
