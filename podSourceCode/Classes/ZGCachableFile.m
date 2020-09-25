//
//  LTVideoModel.m
//  LTVideoDownloadDemo
//
//  Created by 刘涛 on 2019/5/28.
//  Copyright © 2019 刘涛. All rights reserved.
//

#import "ZGCachableFile.h"
#import "ZGDownloadManager.h"

NSString * const ZGCachableFileKey_FileType = @"fileType";
NSString * const ZGCachableFileKey_FileFormat = @"fileFormat";
NSString * const ZGCachableFileKey_CourseID = @"courseID";
NSString * const ZGCachableFileKey_CourseName = @"courseName";
NSString * const ZGCachableFileKey_FileName = @"fileName";
NSString * const ZGCachableFileKey_LessonID = @"lessonID";
NSString * const ZGCachableFileKey_FileID = @"fileID";
NSString * const ZGCachableFileKey_FileSize = @"fileSize";
NSString * const ZGCachableFileKey_FileURL = @"fileURL";
NSString * const ZGCachableFileKey_CourseTitle = @"courseTitle";
NSString * const ZGCachableFileKey_FileUrl = @"fileUrl";
NSString * const ZGCachableFileKey_Duration = @"duration";
NSString * const ZGCachableFileKey_Key = @"key";
NSString * const ZGCachableFileKey_CourseImageUrl = @"courseImageUrl";
NSString * const ZGCachableFileKey_DownloadStatus = @"downloadState";
NSString * const ZGCachableFileKey_DownloadProgress = @"downloadProgress";
NSString * const ZGCachableFileKey_Download_source = @"download_source";
NSString * const ZGCachableFileKey_AdditionalInfo = @"extraInfo";
NSString * const ZGCachableFileKey_Reserved = @"reserved";

@interface ZGCachableFile()

@end

@implementation ZGCachableFile

- (NSString *)cachedFolderPath{
    NSString *suffixFolderPath = [NSString stringWithFormat:@"Documents/DownloadFiles/%@/%@",[ZGDownloadManager sharedManager].currentAccount,self.fileID];
    NSString *fullPath = [NSHomeDirectory() stringByAppendingPathComponent:suffixFolderPath];
    
    return fullPath;
}

- (NSString *)fileID{
    return [NSString stringWithFormat:@"%@_%@_%@", [self fileTypeString], self.courseID, self.lessonID];
}

- (NSString *)fileTypeString{
    if (self.fileType == ZGCachableFileType_video) {
        return @"video";
    } else if (self.fileType == ZGCachableFileType_replay) {
        return @"replay";
    } else if (self.fileType == ZGCachableFileType_document) {
        return @"document";
    }
    return @"";
}

- (BOOL)isEqual:(id)object{
    if ([object isKindOfClass:[ZGCachableFile class]]) {
        ZGCachableFile *model = (ZGCachableFile *)object;
        return [model.fileID isEqualToString:self.fileID];
    }
    return [super isEqual:object];
}

- (void)setDownloadStatus:(ZGCacheStatus)downloadState{
    if (!NSThread.currentThread.isMainThread) {
        NSLog(@"WTF!,不是主线程？");
    }
    _downloadStatus = downloadState;
}

- (void)setDownloadProgress:(CGFloat)downloadProgress {
    _downloadProgress = downloadProgress;
    if (downloadProgress >= 1.0 && _downloadStatus != ZGCacheStatus_finished) {
        self.downloadStatus = ZGCacheStatus_finished;
    }
}

- (void)dealloc{
    NSLog(@"LTVideoDownload---dsdds123");
}

@end
