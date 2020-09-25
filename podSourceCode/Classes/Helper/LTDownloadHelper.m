//
//  LTDownloadHelper.m
//  LTVideoDownloadDemo
//
//  Created by 刘涛 on 2020/7/2.
//  Copyright © 2020 刘涛. All rights reserved.
//

#import "LTDownloadHelper.h"

#define LTResumeDataFolderPath [NSHomeDirectory() stringByAppendingString:@"/Documents/DownloadFiles/ResumeData"]

@implementation LTDownloadHelper

#pragma mark -获取resumeData
+ (NSData *)fetchResumeDataOfDownloadFileWithID:(NSString *)fileID{
    //如果有resumeData，直接继续下载
    NSString *resumeDataFilePath = [NSString stringWithFormat:@"%@/%@_resume.data", LTResumeDataFolderPath, fileID];
    
    NSData *resumeData;
    if ([[NSFileManager defaultManager] fileExistsAtPath:resumeDataFilePath]) {
        NSData *data = [NSData dataWithContentsOfFile:resumeDataFilePath];
        if (data.length > 0) {
            resumeData = data;
        }
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:resumeDataFilePath error:&error];
    }
    return resumeData;
}

#pragma mark -存储resumeData
+ (void)saveResumeData:(NSData *)resumeData withFileID:(NSString *)fileID{
    if (!resumeData) {
        return;
    }
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *folder = [LTResumeDataFolderPath stringByDeletingLastPathComponent];
    if (![manager fileExistsAtPath:folder]) {
        NSError *error;
        [manager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"WTF!，创建folder出错");
            return;
        }
    }
    NSString *path = [NSString stringWithFormat:@"%@/%@_resume.data", LTResumeDataFolderPath, fileID];
    
    [manager createFileAtPath:path contents:resumeData attributes:nil];
}


@end
