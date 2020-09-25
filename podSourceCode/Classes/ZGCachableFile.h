//
//  LTVideoModel.h
//  LTVideoDownloadDemo
//
//  Created by 刘涛 on 2019/5/28.
//  Copyright © 2019 刘涛. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_FileType;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_FileFormat;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_CourseID;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_CourseName;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_FileName;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_LessonID;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_FileID;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_FileSize;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_FileURL;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_CourseTitle;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_FileUrl;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_Key;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_Duration;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_CourseImageUrl;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_DownloadStatus;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_DownloadProgress;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_Download_source;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_AdditionalInfo;
FOUNDATION_EXPORT NSString * _Nonnull const ZGCachableFileKey_Reserved;

typedef NS_ENUM(NSUInteger, ZGCachableFileType) {
    ZGCachableFileType_video,        //视频
    ZGCachableFileType_replay,       //回放
    ZGCachableFileType_document      //资料
};

typedef NS_ENUM(NSUInteger, ZGCacheStatus) {
    ZGCacheStatus_willBegin,        //即将下载
    ZGCacheStatus_inDownloading,    //正在下载
    ZGCacheStatus_suspend,          //已暂停
    ZGCacheStatus_finished,         //已完成
    ZGCacheStatus_failed            //缓存失败
};

NS_ASSUME_NONNULL_BEGIN
@interface ZGCachableFile : NSObject

@property (nonatomic, assign)ZGCachableFileType fileType;   //文件类型
@property (nonatomic, copy)NSString *fileFormat;            //文件格式（pdf、html、rar等，资料文件会用到）
@property (nonatomic, copy)NSString *courseID;             //课程ID
@property (nonatomic, copy)NSString *courseName;            //课程的名字
@property (nonatomic, copy)NSString *lessonID;             //课件ID（一门课程下有很多课件）
@property (nonatomic, copy)NSString *lessonName;            //课件名称
@property (nonatomic, copy, readonly)NSString *fileID;      //文件类型、课程id、课件id 拼接而成 如：video_001_002
@property (nonatomic, assign)NSUInteger fileSize;           //文件大小
@property (nonatomic, copy)NSString *fileURL;               //文件远程地址
@property (nonatomic, copy, readonly)NSString *cachedFolderPath;            //本地缓存地址
@property (nonatomic, copy)NSString *duration;              //时长（视频和回放用到）
@property (nonatomic, copy)NSString *courseImageURL;       //课程图片链接
@property (nonatomic, copy)NSString *key;                  //文件秘钥

@property (nonatomic, assign)ZGCacheStatus downloadStatus;  //文件下载状态
@property (nonatomic, assign)CGFloat downloadProgress;     //文件下载进度
@property (nonatomic, copy)NSString *download_source;      //下载来源
@property (nonatomic, strong) id <NSCoding> additionalInfo; //附加信息（可以用来存储观看时长、学习状态等信息、课程是否过期等信息）
@property (nonatomic, copy)NSString *reserved;             //保留字段

@end

NS_ASSUME_NONNULL_END
