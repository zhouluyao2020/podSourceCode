#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "HCKeepBGRunManager.h"
#import "ZGCacheDataBase.h"
#import "LTDownloadHelper.h"
#import "NSObject+downloadObserve.h"
#import "ZGCachableFile.h"
#import "ZGDownloader.h"
#import "ZGDownloadManager.h"
#import "ZGGeneralDownloader.h"
#import "ZGM3U8Downloader.h"

FOUNDATION_EXPORT double podSourceCodeVersionNumber;
FOUNDATION_EXPORT const unsigned char podSourceCodeVersionString[];

