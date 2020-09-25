//
//  ZGDownloadManager.h
//  ZGStudentServicesHD
//
//  Created by 刘涛 on 2020/6/1.
//  Copyright © 2020 offcn. All rights reserved.
//

#import <Foundation/Foundation.h>
//缓存的相关数据
#import "ZGDownloader.h"
#import "NSObject+downloadObserve.h"

@class ZGServicePackageManager;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSString *const ZGCacheShouldDownloadNextWaitingFileNotification;
FOUNDATION_EXTERN NSString *const ZGCacheShouldUpdateDatasourceNotification;

@interface ZGDownloadManager : NSObject

@property (nonatomic, assign) NSUInteger maxConcurrentDownloadVideosCount;  //最多同时下载文件数量，默认为3

@property (nonatomic, assign) BOOL allowDownloadViaWWAN;                    //是否允许使用蜂窝网络下载文件

@property (nonatomic, assign) BOOL allowDownloadInBackGround;               //是否允许后台常驻线程下载

@property (nonatomic, strong) NSMutableArray *allManagedFiles;              //所有下载的文件

@property (readonly, nonatomic, copy) NSString *currentAccount;             //当前账号

+ (instancetype)sharedManager;

- (void)bindWithAccount:(NSString *)account;

/// 获取当前正在缓存的文件数量
- (NSUInteger)totalCountOfInCachingFiles;

- (void)download:(ZGCachableFile *)model;

- (void)suspend:(ZGCachableFile *)model;

- (void)remove:(ZGCachableFile *)model;

- (ZGCachableFile *)managedFileOfID:(NSString *)fileID;

@end

NS_ASSUME_NONNULL_END
