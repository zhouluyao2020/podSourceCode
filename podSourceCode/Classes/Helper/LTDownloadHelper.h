//
//  LTDownloadHelper.h
//  LTVideoDownloadDemo
//
//  Created by 刘涛 on 2020/7/2.
//  Copyright © 2020 刘涛. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LTDownloadHelper : NSObject

#pragma mark -获取resumeData
+ (NSData *)fetchResumeDataOfDownloadFileWithID:(NSString *)fileID;

#pragma mark -存储resumeData
+ (void)saveResumeData:(NSData *)resumeData withFileID:(NSString *)fileID;

@end

NS_ASSUME_NONNULL_END
