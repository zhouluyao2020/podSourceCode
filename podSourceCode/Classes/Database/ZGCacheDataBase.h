//
//  LTDatabaseManager.h
//  LTVideoDownloadDemo
//
//  Created by 刘涛 on 2020/6/18.
//  Copyright © 2020 刘涛. All rights reserved.
//

#import <fmdb/FMDB.h>
#import "ZGCachableFile.h"
//#import "ZGCacheClassGroupModel.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSString *const ZGShouldUpdateDatabaseNotification;

@interface ZGCacheDataBase : FMDatabase

+ (void)resetDatabaseWithAccount:(NSString *)account;

+ (NSArray <ZGCachableFile *>*)allFilesInDatabase;

+ (BOOL)insertDownloadFile:(ZGCachableFile *)info;

+ (BOOL)updateDownloadFile:(ZGCachableFile *)info;

+ (BOOL)removeDownloadFile:(ZGCachableFile *)info;

//+ (NSArray <ZGCachableFile *>*)allFilesWhereKeyIs:(NSString *)key andValueIs:(NSString *)value;
//+ (NSArray <ZGCachableFile *>*)allFilesWhereKeyIs:(NSString *)key andValueIsNot:(NSString *)value;
//+ (NSArray <ZGCachableFile *>*)allFilesWhereKeysAre:(NSArray <NSString *> *)keys andValuesAre:(NSArray <NSString *> *)values isEqual:(BOOL)isEqual;

//一些便捷方法

//+ (NSArray <ZGCacheClassGroupModel *>*)allDownloadedFilesGroupedByCourseID;

@end

NS_ASSUME_NONNULL_END
