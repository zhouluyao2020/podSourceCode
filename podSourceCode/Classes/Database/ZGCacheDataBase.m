//
//  LTDatabaseManager.m
//  LTVideoDownloadDemo
//
//  Created by 刘涛 on 2020/6/18.
//  Copyright © 2020 刘涛. All rights reserved.
//

#import "ZGCacheDataBase.h"
#import "ZGDownloadManager.h"
#import "ZGDownloadManager.h"

NSString *const ZGShouldUpdateDatabaseNotification = @"ZGShouldUpdateDatabaseNotification";

#define ZGCacheFilesTable @"ZGCacheFilesTable"

@implementation ZGCacheDataBase

static ZGCacheDataBase *_database;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self resetDatabaseWithAccount:[ZGDownloadManager sharedManager].currentAccount];
        [self createDownloadTableIfNeeded];
        [self resetDownloadStateOfUnfinishedFiles];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDownloadViewdeosTable) name:ZGShouldUpdateDatabaseNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDownloadViewdeosTable) name:UIApplicationDidEnterBackgroundNotification object:nil];
    });
}

+ (void)resetDatabaseWithAccount:(NSString *)account{
//    NSAssert(account, @"缓存模块需要获取用户的account（手机号），用于区分不同用户，请先调用registWithAccount：方法注册用户");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSString *existPath = [NSString stringWithFormat:@"%@/Documents/DownloadFiles/%@",NSHomeDirectory(),account];
    if (![fileManager fileExistsAtPath:existPath]) {
        [fileManager createDirectoryAtPath:existPath withIntermediateDirectories:YES attributes:nil error:&error];
    }
    NSString *path=[NSString stringWithFormat:@"%@/Documents/DownloadFiles/%@/database.sqlite",NSHomeDirectory(),account];
    _database = [super databaseWithPath:path];
    
    if ([_database open]) {
        NSLog(@"create database success");
    }else{
        NSLog(@"create database failed");
    }
    
}

//19pad 整理
+ (void)createDownloadTableIfNeeded{
    
    NSMutableString *instructStr = [[NSString stringWithFormat:@"create table if not exists '%@'", ZGCacheFilesTable] mutableCopy];
    [instructStr appendString:@"("];
    [instructStr appendFormat:@"%@ text primary key", ZGCachableFileKey_FileID];
    NSArray *keys_string = @[
        ZGCachableFileKey_FileFormat,
        ZGCachableFileKey_CourseID, 
        ZGCachableFileKey_CourseName,
        ZGCachableFileKey_FileName,
        ZGCachableFileKey_LessonID,
        ZGCachableFileKey_FileURL,
        ZGCachableFileKey_Duration,
        ZGCachableFileKey_Key,
        ZGCachableFileKey_CourseImageUrl,
        ZGCachableFileKey_Download_source,
        ZGCachableFileKey_Reserved
    ];
    
    NSArray *keys_data = @[
        ZGCachableFileKey_AdditionalInfo
    ];
    
    NSArray *keys_int = @[
        ZGCachableFileKey_FileType,
        ZGCachableFileKey_FileSize,
        ZGCachableFileKey_DownloadStatus
    ];
    
    NSArray *keys_float = @[
        ZGCachableFileKey_DownloadProgress
    ];
    
    
    for (NSString *key in keys_string) {
        [instructStr appendFormat:@",%@ text NOT NULL", key];
    }
    for (NSString *key in keys_data) {
        [instructStr appendFormat:@",%@ data NOT NULL", key];
    }
    for (NSString *key in keys_int) {
        [instructStr appendFormat:@",%@ integer NOT NULL", key];
    }
    for (NSString *key in keys_float) {
        [instructStr appendFormat:@",%@ float NOT NULL", key];
    }
    
    [instructStr appendString:@")"];
    
    BOOL isSucceed = [_database executeUpdate:instructStr];
    if (isSucceed) {
        NSLog(@"create table success");
        //数据迁移，在新表中插入旧版本数据库的相关数据
        [self migrateIfNeeded];
    }else{
        NSLog(@"create table failed");
    }
}

+ (void)resetDownloadStateOfUnfinishedFiles{
    NSString *state = [NSString stringWithFormat:@"%@='%lu'",ZGCachableFileKey_DownloadStatus, ZGCacheStatus_suspend];
    NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@ <> '%ld'",ZGCacheFilesTable,state,ZGCachableFileKey_DownloadStatus,ZGCacheStatus_finished];
    
    BOOL updateSuccess = [_database executeUpdate:sql];
    if (updateSuccess) {
        NSLog(@"更新成功");
    } else {
        NSLog(@"更新失败");
    }
}

#pragma mark -增
+ (BOOL)insertDownloadFile:(ZGCachableFile *)model
{
    NSDictionary *dic = @{
        ZGCachableFileKey_FileType:     @(model.fileType),
        ZGCachableFileKey_FileFormat:   model.fileFormat ?: @"",
        ZGCachableFileKey_CourseID:     model.courseID ?: @"",
        ZGCachableFileKey_CourseName:   model.courseName ?: @"",
        ZGCachableFileKey_FileName:     model.lessonName ?: @"",
        ZGCachableFileKey_LessonID:     model.lessonID ?: @"",
        ZGCachableFileKey_FileID:       model.fileID ?: @"",
        ZGCachableFileKey_FileSize:     @(model.fileSize),
        ZGCachableFileKey_FileURL:      model.fileURL ?: @"",
        ZGCachableFileKey_Duration:     model.duration ?: @"",
        ZGCachableFileKey_Key:          model.key ?: @"",
        ZGCachableFileKey_CourseImageUrl:   model.courseImageURL ?: @"",
        ZGCachableFileKey_DownloadStatus:    @(model.downloadStatus),
        ZGCachableFileKey_DownloadProgress: @(model.downloadProgress),
        ZGCachableFileKey_Download_source:  model.download_source ?: @"",
        ZGCachableFileKey_AdditionalInfo:   [NSKeyedArchiver archivedDataWithRootObject:model.additionalInfo] ?: @"",
        ZGCachableFileKey_Reserved: model.reserved ?: @""
    };
    
    NSMutableArray *keys = [NSMutableArray array];
    NSMutableArray *values = [NSMutableArray array];
    for (NSString *key in dic.allKeys) {
        [keys addObject:key];
        NSString *value = [NSString stringWithFormat:@"'%@'",dic[key]];
        [values addObject:value];
    }
    
    NSString *keysString = [keys componentsJoinedByString:@","];
    NSString *valuesString = [values componentsJoinedByString:@","];
    
    NSString *sqlString = [NSString stringWithFormat:@"insert into %@(%@) values (%@);",ZGCacheFilesTable, keysString, valuesString];
    
    if ([_database executeUpdate:sqlString]) {
        NSLog(@"插入成功");
//        NSUInteger status = 0;
//        if ([tableName isEqualToString:DOWNLOADINGDB]) {
//            status = 1;
//        } else if ([tableName isEqualToString:FINISHDB]) {
//            status = 2;
//            [[NSNotificationCenter defaultCenter] postNotificationName:ZGCacheFileDidDownloadSuccessNotification object:nil];
//        }
//        [ZGDownloadStatusObserver observerOfID:videoModel.downloadName didChangedownloadStatus:status];
        return YES;
    }else{
        NSLog(@"插入失败");
        return NO;
    }
}

#pragma mark -查
+ (NSArray *)allFilesInDatabase{
    FMResultSet *set = [_database executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@",ZGCacheFilesTable]];
    NSMutableArray *items = [NSMutableArray array];
    while ([set next]) {
        ZGCachableFile *fileModel = [ZGCachableFile new];
        fileModel.fileType = [set intForColumn:ZGCachableFileKey_FileType];
        fileModel.fileFormat = [set stringForColumn:ZGCachableFileKey_FileFormat];
        fileModel.lessonName = [set stringForColumn:ZGCachableFileKey_FileName];
        fileModel.fileSize = [set intForColumn:ZGCachableFileKey_FileSize];
        fileModel.courseID = [set stringForColumn:ZGCachableFileKey_CourseID];
        fileModel.courseName = [set stringForColumn:ZGCachableFileKey_CourseName];
        fileModel.lessonID = [set stringForColumn:ZGCachableFileKey_LessonID];
        fileModel.fileURL = [set stringForColumn:ZGCachableFileKey_FileURL];
        fileModel.downloadStatus = [set intForColumn:ZGCachableFileKey_DownloadStatus];
        fileModel.downloadProgress = [set doubleForColumn:ZGCachableFileKey_DownloadProgress];
        fileModel.courseImageURL = [set stringForColumn:ZGCachableFileKey_CourseImageUrl];
        fileModel.download_source = [set stringForColumn:ZGCachableFileKey_Download_source];
        fileModel.additionalInfo = [set stringForColumn:ZGCachableFileKey_AdditionalInfo];
        fileModel.reserved = [set stringForColumn:ZGCachableFileKey_Reserved];
        fileModel.duration = [set stringForColumn:ZGCachableFileKey_Duration];
        fileModel.key = [set stringForColumn:ZGCachableFileKey_Key];
        [items addObject:fileModel];
    }
    return items;
}


///// 某门课程下所有文件
//+ (NSArray <ZGCacheClassGroupModel *>*)allDownloadedFilesGroupedByCourseID{
//    NSString *sql = [NSString stringWithFormat:@"SELECT *, COUNT(DISTINCT %@) from %@ WHERE %@='%lu' group by %@",ZGCachableFileKey_CourseID, ZGCacheFilesTable, ZGCachableFileKey_DownloadStatus, ZGCacheStatus_finished, ZGCachableFileKey_CourseID];
//    
//    FMResultSet *set = [_database executeQuery:sql];//
//
//    NSMutableArray *courseIDs = [NSMutableArray array];
//    while ([set next]) {
//        [courseIDs addObject:[set stringForColumn:ZGCachableFileKey_CourseID]];
//    }
//    
//    NSMutableArray *results = [NSMutableArray array];
//    for (NSString *courseID in courseIDs) {
//
//        ZGCacheClassGroupModel *model = [ZGCacheClassGroupModel new];
//        model.courseID = courseID;
//        
//        sql = [NSString stringWithFormat:@"select *from %@ where %@='%@' and %@='%lu'",ZGCacheFilesTable,ZGCachableFileKey_CourseID, courseID,ZGCachableFileKey_DownloadStatus,ZGCacheStatus_finished];
//        FMResultSet *set = [_database executeQuery:sql];
//        
//        
//        while ([set next]) {
//            
//            if (!model.courseName) {
//                model.courseName = [set stringForColumn:ZGCachableFileKey_CourseName];
//            }
//            
//            model.totalSize += [set stringForColumn:@"fileSize"].floatValue;
//            model.count += 1;
//        }
//        
//        [results addObject:model];
//    }
//    
//    return results;
//}


#pragma mark -改
+ (BOOL)updateDownloadFile:(ZGCachableFile *)model{
    NSString *state = [NSString stringWithFormat:@"%@='%lu'",ZGCachableFileKey_DownloadStatus, model.downloadStatus];
    NSString *progress = [NSString stringWithFormat:@"%@='%f'",ZGCachableFileKey_DownloadProgress, model.downloadProgress];
    
    //    if (model.downloadProgress == 1 && model.downloadStatus != ZGCacheStatus_finished) {
    //        NSLog(@"1111");
    //    }
    
    NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@,%@ WHERE %@ = '%@'",ZGCacheFilesTable,state,progress,ZGCachableFileKey_FileID,model.fileID];
    
    BOOL updateSuccess = [_database executeUpdate:sql];
    
    return updateSuccess;
}

#pragma mark -删
+ (BOOL)removeDownloadFile:(ZGCachableFile *)file{
    NSMutableString *mutStr = [[NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = '%@'", ZGCacheFilesTable, ZGCachableFileKey_FileID, file.fileID] mutableCopy];
    
    BOOL isSucceed = [_database executeUpdate:[mutStr copy]];
    if (isSucceed) {
        //移除设备上的文件
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:file.cachedFolderPath error:&error];
        if (error) {
            NSLog(@"沙盒文件删除出错：%@",error);
        }
    } else {
        NSLog(@"数据库移除出错");
    }
    
    return isSucceed;
}

#pragma mark 用户退出应用时更新视频下载数据
+ (void)updateDownloadViewdeosTable{
    return;
    //先遍历一遍内存中的下载列表和数据库中记录的列表，如果数据库中的数据在内存中不存在（该视频被删除），则删除数据库中的记录，并移除本地文件
    NSArray *videosInDatabase = [self allFilesInDatabase];
    for (ZGCachableFile *videoModel in videosInDatabase) {
        if (![[ZGDownloadManager sharedManager].allManagedFiles containsObject:videoModel]) {
            //移除数据库中的记录
            BOOL success = [self removeDownloadFile:videoModel];
            if (success) {
                //移除设备上的文件
                NSError *error;
                [[NSFileManager defaultManager] removeItemAtPath:videoModel.cachedFolderPath error:&error];
                if (error) {
                    NSLog(@"沙盒文件删除出错：%@",error);
                }
            } else {
                NSLog(@"数据库移除出错");
            }
        }
    }
    
    //如果内存中有新数据，但 database 中不存在该 model，将新数据插入到数据库中
    for (ZGCachableFile *videoModel in [ZGDownloadManager sharedManager].allManagedFiles) {
        if (![[self allFilesInDatabase] containsObject:videoModel]) {
            [ZGCacheDataBase insertDownloadFile:videoModel];
            continue;
        }
        
//        if (videoModel.downloadProgress >= 1.0 && videoModel.downloadStatus != ZGCacheStatus_finished) {
//            NSLog(@"LTVideoDownload---出现了进度大于1，但下载状态是'未完成'的情况");
//            //将下载状态改为'已完成'
//            videoModel.downloadStatus = ZGCacheStatus_finished;
//        }
        
        BOOL updateSuccess = [ZGCacheDataBase updateDownloadFile:videoModel];

        if (!updateSuccess) {
            NSLog(@"LTVideoDownload---未更新成功");
        }
    }
}

//+ (NSArray *)allFilesWhereKeyIs:(NSString *)key andValueIs:(NSString *)value{
//    return [self allFilesWhereKeysAre:@[key] andValuesAre:@[value] isEqual:YES];
//}
//
//+ (NSArray <ZGCachableFile *>*)allFilesWhereKeyIs:(NSString *)key andValueIsNot:(NSString *)value{
//    return [self allFilesWhereKeysAre:@[key] andValuesAre:@[value] isEqual:false];
//}
//
//+ (NSArray <ZGCachableFile *>*)allFilesWhereKeysAre:(NSArray <NSString *> *)keys andValuesAre:(NSArray <NSString *> *)values isEqual:(BOOL)isEqual{
//    
//    NSMutableArray *conditions = [NSMutableArray array];
//    NSString *symbol = @"=";
//    if (!isEqual) {
//        symbol = @"<>";
//    }
//    
//    for (int i=0; i<keys.count; i++) {
//        NSString *key = keys[i];
//        NSString *value = values[i];
//        [conditions addObject:[NSString stringWithFormat:@"%@ %@ %@", key, symbol, value]];
//    }
//    
//    NSString *conditionStr = [conditions componentsJoinedByString:@" AND "];
//    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@", ZGCacheFilesTable, conditionStr];
//    FMResultSet *set = [_database executeQuery:sql];
//    NSMutableArray *items = [NSMutableArray array];
//    while ([set next]) {
//        ZGCachableFile *fileModel = [ZGCachableFile new];
//        fileModel.fileType = [set intForColumn:ZGCachableFileKey_FileType];
//        fileModel.fileFormat = [set stringForColumn:ZGCachableFileKey_FileFormat];
//        fileModel.lessonName = [set stringForColumn:ZGCachableFileKey_FileName];
//        fileModel.fileSize = [set intForColumn:ZGCachableFileKey_FileSize];
//        fileModel.courseID = [set stringForColumn:ZGCachableFileKey_CourseID];
//        fileModel.courseName = [set stringForColumn:ZGCachableFileKey_CourseName];
//        fileModel.lessonID = [set stringForColumn:ZGCachableFileKey_LessonID];
//        fileModel.fileURL = [set stringForColumn:ZGCachableFileKey_FileURL];
//        fileModel.downloadStatus = [set intForColumn:ZGCachableFileKey_DownloadStatus];
//        fileModel.downloadProgress = [set doubleForColumn:ZGCachableFileKey_DownloadProgress];
//        fileModel.courseImageURL = [set stringForColumn:ZGCachableFileKey_CourseImageUrl];
//        fileModel.download_source = [set stringForColumn:ZGCachableFileKey_Download_source];
//        fileModel.reserved = [set stringForColumn:ZGCachableFileKey_AdditionalInfo];
//        fileModel.duration = [set stringForColumn:ZGCachableFileKey_Duration];
//        [items addObject:fileModel];
//    }
//    return items;
//}

#pragma mark -数据迁移（旧版本下载的数据更新到新版本）
+ (void)migrateIfNeeded{
    //如果没有旧的缓存数据，直接返回
    FMDatabase *oldDatabase = [self oldDatabaseOfCurrentAccount];
    if (!oldDatabase) {
        return;
    }
    //1.数据库迁移
    [self _migrateDataInOldDatabase:oldDatabase];
    
    //2.缓存文件迁移（更改文件名、目录等）
    
}

+ (FMDatabase *)oldDatabaseOfCurrentAccount{
    NSString *newDataBasePath = _database.databasePath;
    NSString *oldDataBasePath = [_database.databasePath stringByReplacingOccurrencesOfString:@"DownloadFiles" withString:@"Downloads"];
    oldDataBasePath = [oldDataBasePath stringByReplacingOccurrencesOfString:@"database.sqlite" withString:@"DownloadInfo.sqlite"];
    if ([newDataBasePath containsString:@"游客"]) {
        //旧版本未登录账号的数据库在/Documents/Downloads/(null)目录下
        oldDataBasePath = [oldDataBasePath stringByReplacingOccurrencesOfString:@"游客" withString:@"(null)"];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:oldDataBasePath]) {
        FMDatabase *database = [FMDatabase databaseWithPath:oldDataBasePath];
        [database open];
        return database;
    }
    return nil;
}

+ (void)_migrateDataInOldDatabase:(FMDatabase *)oldDatabase{
    
    NSMutableArray *cachableFilesInOldDatabase = [NSMutableArray array];
    
//    NSArray *tableNames = @[FINISHDB, DOWNLOADINGDB];
    NSString *finishedTableName = @"finishlist";
    NSString *downloadingTableName = @"downinglist";
    NSArray *tableNames = @[finishedTableName, finishedTableName];
    for (NSString *tableName in tableNames) {
        FMResultSet *set = [oldDatabase executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@",tableName]];
        while ([set next]) {
            ZGCachableFile *fileModel = [ZGCachableFile new];
            //文件类型
            NSString *fileType = [set stringForColumn:@"resourceType"];
            if ([fileType isEqualToString:@"1"] ) {
                fileModel.fileType = ZGCachableFileType_video;
            } else if ([fileType isEqualToString:@"9"] ) {
                fileModel.fileType = ZGCachableFileType_document;
            } else if ([fileType isEqualToString:@"101"] || [fileType isEqualToString:@"202"]) {
                fileModel.fileType = ZGCachableFileType_replay;
            } else {
                //不知道什么类型，不迁移该数据
                continue;
            }
            NSString *courseID_lessonID = [set stringForColumn:@"fileName"];
            NSString *courseID = [courseID_lessonID componentsSeparatedByString:@"_"][0];
            NSString *lessonID = [courseID_lessonID componentsSeparatedByString:@"_"][1];
            //文件后缀名
            if (fileModel.fileType == ZGCachableFileType_document) {
                fileModel.fileFormat = [set stringForColumn:@"fileType"];
                if (fileModel.fileFormat.length == 0) {
                    fileModel.fileFormat = @"(null)"; //旧数据库中有的后缀为.(null)
                }
            }
            
            fileModel.lessonName = [set stringForColumn:@"fileTitle"];
            fileModel.fileSize = [set stringForColumn:@"fileSize"].intValue;
            fileModel.courseID = courseID;
            fileModel.courseName = [set stringForColumn:@"courseTitle"];
            fileModel.lessonID = lessonID;
            fileModel.fileURL = [set stringForColumn:@"fileUrl"];
            if ([tableName isEqualToString:finishedTableName]) {
                fileModel.downloadStatus = ZGCacheStatus_finished;
                fileModel.downloadProgress = 1;
            } else {
                fileModel.downloadStatus = ZGCacheStatus_suspend;
                //FIXME:旧版本未记录进度
                fileModel.downloadProgress = 0.0;
            }
            fileModel.courseImageURL = [set stringForColumn:@"imgUrl"];
            fileModel.download_source = @"";
            fileModel.reserved = @"";
            //FIXME:旧版本未记录视频时长，如何处理
            fileModel.duration = @"";
            
            [cachableFilesInOldDatabase addObject:fileModel];
        }
    }
    
    BOOL success = YES;
    for (ZGCachableFile *file in cachableFilesInOldDatabase) {
        BOOL insertSuccess = [self insertDownloadFile:file];
        if (!insertSuccess) {
            NSLog(@"迁移失败");
            success = NO;
        }
    }
    
    if (success) {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:oldDatabase.databasePath error:&error];
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            //更名、更改文件夹
            [self _migrateCachedFiles:cachableFilesInOldDatabase];
        });
    }
    
}

+ (void)_migrateCachedFiles:(NSArray <ZGCachableFile *>*)oldFiles{
    NSString *userFolder = [_database.databasePath stringByReplacingOccurrencesOfString:@"/database.sqlite" withString:@""];
    NSString *oldUserFolder = [userFolder stringByReplacingOccurrencesOfString:@"/DownloadFiles/" withString:@"/Downloads/"];
    if ([oldUserFolder containsString:@"游客"]) {
        oldUserFolder = [oldUserFolder stringByReplacingOccurrencesOfString:@"游客" withString:@"(null)"];
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
   
    //把旧用户文件夹中的文件拷贝到新用户文件夹下
    [self copyFilesInFolder:oldUserFolder toFolder:userFolder];
    NSError *error;
    //移动完成后，修改各下载文件的相关文件名
    for (ZGCachableFile *file in oldFiles) {
        if (file.fileType == ZGCachableFileType_document) {
            NSString *oldDocFileName = [NSString stringWithFormat:@"%@_%@_file.%@",file.courseID,file.lessonID,file.fileFormat ?: @"(null)"];
            NSString *oldFilePath = [userFolder stringByAppendingPathComponent:oldDocFileName];
            if (![fileManager fileExistsAtPath:oldFilePath]) {
                continue;
            }
            NSString *newDocFileName = [NSString stringWithFormat:@"Document_%@_%@.%@",file.courseID,file.lessonID,file.fileFormat ?: @"(null)"];
            NSString *newFilePath = [userFolder stringByAppendingPathComponent:newDocFileName];
            [fileManager copyItemAtPath:oldFilePath toPath:newFilePath error:&error];
            if (error) {
                NSLog(@"WTF!，出错1");
            }
            [fileManager removeItemAtPath:oldFilePath error:&error];
            if (error) {
                NSLog(@"WTF!，出错2");
            }
        } else {
            
            NSString *oldFileFolderName = [NSString stringWithFormat:@"%@_%@",file.courseID,file.lessonID];
            NSString *newFileFolderName = [NSString stringWithFormat:@"Video_%@_%@",file.courseID,file.lessonID];
            if (file.fileType == ZGCachableFileType_replay) {
                newFileFolderName = [NSString stringWithFormat:@"Replay_%@_%@",file.courseID,file.lessonID];
            }
            NSString *oldFileFolderPath = [userFolder stringByAppendingPathComponent:oldFileFolderName];
            NSString *newFileFolderPath = [userFolder stringByAppendingPathComponent:newFileFolderName];
            if (![fileManager fileExistsAtPath:newFileFolderPath]) {
                [fileManager createDirectoryAtPath:newFileFolderPath withIntermediateDirectories:YES attributes:nil error:&error];
                if (error) {
                    NSLog(@"WTF!，出错3");
                }
            }
            [self copyFilesInFolder:oldFileFolderPath toFolder:newFileFolderPath];
            if (error) {
                NSLog(@"WTF!，出错4");
            }
            
            //修改文件夹内子文件名
            if (file.fileType == ZGCachableFileType_video) {//视频
                NSString *oldM3u8FileName = [NSString stringWithFormat:@"%@_%@.m3u8",file.courseID, file.lessonID];
                NSString *newM3u8FileName = [NSString stringWithFormat:@"m3u8_%@_%@.m3u8",file.courseID, file.lessonID];
                NSString *oldM3u8FilePath = [newFileFolderPath stringByAppendingPathComponent:oldM3u8FileName];
                NSString *newM3u8FilePath = [newFileFolderPath stringByAppendingPathComponent:newM3u8FileName];
                [fileManager moveItemAtPath:oldM3u8FilePath toPath:newM3u8FilePath error:&error];
            } else {//回放
                NSString *oldChatFileName = [NSString stringWithFormat:@"chat_%@_%@.json",file.courseID, file.lessonID];
                NSString *newChatFileName = @"chat.json";
                NSString *oldChatFilePath = [newFileFolderPath stringByAppendingPathComponent:oldChatFileName];
                NSString *newChatFilePath = [newFileFolderPath stringByAppendingPathComponent:newChatFileName];
                [fileManager moveItemAtPath:oldChatFilePath toPath:newChatFilePath error:&error];
                
                NSString *oldCmdFileName = [NSString stringWithFormat:@"cmd_%@_%@.json",file.courseID, file.lessonID];
                NSString *newCmdFileName = @"cmd.json";
                NSString *oldCmdFilePath = [newFileFolderPath stringByAppendingPathComponent:oldCmdFileName];
                NSString *newCmdFilePath = [newFileFolderPath stringByAppendingPathComponent:newCmdFileName];
                [fileManager moveItemAtPath:oldCmdFilePath toPath:newCmdFilePath error:&error];
            }
        }
    }
}

+ (void)copyFilesInFolder:(NSString *)sourceFolder toFolder:(NSString *)toFolder{
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSArray* array = [fileManager contentsOfDirectoryAtPath:sourceFolder error:nil];
    for(int i = 0; i<[array count]; i++){
        NSString *fullPath = [sourceFolder stringByAppendingPathComponent:[array objectAtIndex:i]];
        NSString *fullToPath = [toFolder stringByAppendingPathComponent:[array objectAtIndex:i]];
        NSLog(@"%@",fullPath);
        NSLog(@"%@",fullToPath);
        //判断是不是文件夹
        BOOL isFolder = NO;
        //判断是不是存在路径 并且是不是文件夹
        BOOL isExist = [fileManager fileExistsAtPath:fullPath isDirectory:&isFolder];
        if (isExist){
            NSError *err = nil;
            [[NSFileManager defaultManager] copyItemAtPath:fullPath toPath:fullToPath error:&err];
            [[NSFileManager defaultManager] removeItemAtPath:fullPath error:&err];
            if (err) {
                NSLog(@"WTF!，出错5");
            }
            NSLog(@"%@",err);
            if (isFolder){
                [self copyFilesInFolder:fullPath toFolder:fullToPath];
            }
        }
    }
    
    NSError *error;
    [fileManager removeItemAtPath:sourceFolder error:&error];
    if (error) {
        NSLog(@"WTF!，出错6");
    }
}

//+ (void)moveItemAtPath:(NSString *)fromPath toPath:(NSString *)toPath{
//
//}

@end
