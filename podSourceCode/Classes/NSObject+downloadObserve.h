//
//  LTDownloadStatusObserver.h
//  LTVideoTool
//
//  Created by 刘涛 on 2020/6/5.
//  Copyright © 2020 offcn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZGCachableFile.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject(downloadObserve)

//下载状态回调block
typedef void(^DownloadStatusCallback)(ZGCacheStatus downloadStatus);

//下载进度回调block
typedef void(^DownloadProgressCallback)(float progress);

//下载速度回调block
typedef void(^DownloadSpeedCallback)(float speed);

//下载错误回调
typedef void(^DownloadErrorHandle)(NSError *error);


/// 监听某个文件的下载状态，一对多监听，会同时监多个file的下载状态，如果只是一对一监听，需要先手动调用stopObserveDownloadFileOfID
/// @param fileID 下载的文件ID
/// @param statusCallback 状态回调
/// @param progressCallback 进度回调
/// @param speedCallback 进度回调 回调的关联的对象（该对象销毁时，会释放其对应的回调，如果传nil，则回调在文件下载成功后被移除）
/// @param errorHandle 错误处理
- (void)observeDownloadFileOfID:(NSString *)fileID
         withStatusCallback:(DownloadStatusCallback _Nullable)statusCallback
           progressCallback:(DownloadProgressCallback _Nullable)progressCallback
              speedCallback:(DownloadSpeedCallback _Nullable)speedCallback
                handleError:(DownloadErrorHandle _Nullable)errorHandle;

- (void)stopObserveDownloadFileOfID:(NSString *)fileID;

- (void)stopObserve;

+ (void)observersOfFile:(ZGCachableFile *)file shouldUpdateDownloadSpeed:(CGFloat)speed;

+ (void)observersOfFile:(ZGCachableFile *)file shouldDisposeError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
