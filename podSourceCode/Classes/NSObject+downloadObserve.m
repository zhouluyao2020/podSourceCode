//
//  LTDownloadStatusObserver.m
//  LTVideoTool
//
//  Created by 刘涛 on 2020/6/5.
//  Copyright © 2020 offcn. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "ZGCachableFile.h"
#import "ZGDownloadManager.h"

/// 所有的observer, 如下面的结构
///  [  fileID1:observer1,
///   fileID2:observer1,...]

@interface LTAssociateObjectWrapper : NSObject

@property (nonatomic, weak) id associatedObj;

@end

@implementation LTAssociateObjectWrapper

@end

@interface LTDeallocNotifier : NSObject

@property (nonatomic, weak) NSObject *target;

@property (nonatomic, copy) void(^deallocBlock)(void);

@end

@implementation LTDeallocNotifier

- (void)dealloc {
    if (self.deallocBlock) {
        self.deallocBlock();
    }
}

@end

@interface NSObject(deallocNotifier)

@property (nonatomic, strong) LTDeallocNotifier *deallocNotifier;

@end

@interface LTDownloadObserver : NSObject

@property (nonatomic, weak) ZGCachableFile *observedFile;

/// 回调, 如下面的结构
///  [  objctKey1 : [callback1, callback2...],
///   objctKey2 : [callback1, callback2...],...]

@property (nonatomic, copy) NSMapTable <NSString *, NSMutableSet <DownloadStatusCallback> *> *statusCallbackMapTable;

@property (nonatomic, copy) NSMapTable <NSString *, NSMutableSet <DownloadProgressCallback> *> *progressMapTable;

@property (nonatomic, copy) NSMapTable <NSString *, NSMutableSet <DownloadSpeedCallback> *> *speedCallbackMapTable;

@property (nonatomic, copy) NSMapTable <NSString *, NSMutableSet <DownloadErrorHandle> *> *errorHanldes;

@end

@implementation LTDownloadObserver

static NSMapTable <NSString *, LTDownloadObserver *> *observersMapTable;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!observersMapTable) {
            observersMapTable = [NSMapTable strongToStrongObjectsMapTable];
        }
    });
}

- (instancetype)init{
    if (self = [super init]) {
        self.statusCallbackMapTable = [NSMapTable weakToStrongObjectsMapTable];
        self.progressMapTable = [NSMapTable weakToStrongObjectsMapTable];
        self.speedCallbackMapTable = [NSMapTable weakToStrongObjectsMapTable];
        self.errorHanldes = [NSMapTable weakToStrongObjectsMapTable];
    }
    return self;
}

+ (LTDownloadObserver *)observerOfFileID:(NSString *)fileID{
    //所有监听者字典
    if (!observersMapTable) {
        observersMapTable = [NSMapTable weakToStrongObjectsMapTable];
    }
    
    LTDownloadObserver *observer = [observersMapTable objectForKey:fileID];
    ZGCachableFile *downloadFile = [[ZGDownloadManager sharedManager] managedFileOfID:fileID];
    
    if (!observer) {
        observer = [[LTDownloadObserver alloc] init];
        [observersMapTable setObject:observer forKey:fileID];
    } else {
        NSLog(@"wtf,存在观察者");
    }
    observer.observedFile = downloadFile;
    return observer;
}

#pragma mark -追加某个对象的回调到observer中
- (void)addSubscriberWithKey:(NSString *)key
                        statusCallback:(DownloadStatusCallback _Nullable)statusCallback
                      progressCallback:(DownloadProgressCallback _Nullable)progressCallback
                         speedCallback:(DownloadSpeedCallback _Nullable)speedCallback
                           handleError:(DownloadErrorHandle _Nullable)errorHandle {
    if (statusCallback) {
        NSMutableSet *statusCallbacks = [self.statusCallbackMapTable objectForKey:key];
        if (!statusCallbacks) {
            statusCallbacks = [NSMutableSet set];
            [self.statusCallbackMapTable setObject:statusCallbacks forKey:key];
        }
        [statusCallbacks addObject:statusCallback];
    }
    
    if (progressCallback) {
        NSMutableSet *progressCallbacks = [self.progressMapTable objectForKey:key];
        if (!progressCallbacks) {
            progressCallbacks = [NSMutableSet set];
            [self.progressMapTable setObject:progressCallbacks forKey:key];
        }
        [progressCallbacks addObject:progressCallback];
    }
    
    if (speedCallback) {
        NSMutableSet *speedCallbacks = [self.speedCallbackMapTable objectForKey:key];
        if (!speedCallbacks) {
            speedCallbacks = [NSMutableSet set];
            [self.speedCallbackMapTable setObject:speedCallbacks forKey:key];
        }
        [speedCallbacks addObject:speedCallback];
    }
    
    if (errorHandle) {
        NSMutableSet *errorCallbacks = [self.errorHanldes objectForKey:key];
        if (!errorCallbacks) {
            errorCallbacks = [NSMutableSet set];
            [self.errorHanldes setObject:errorCallbacks forKey:key];
        }
        [errorCallbacks addObject:errorHandle];
    }
}

- (void)removeSubscriberWithIdentifier:(NSString *)identifier{
    [self.statusCallbackMapTable removeObjectForKey:identifier];
    [self.progressMapTable removeObjectForKey:identifier];
    [self.speedCallbackMapTable removeObjectForKey:identifier];
    [self.errorHanldes removeObjectForKey:identifier];
}

#pragma mark -KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if ([keyPath isEqualToString:@"downloadStatus"]) {
        ZGCacheStatus status = [change[NSKeyValueChangeNewKey] intValue];
        //依次调用存储的所有block
        for (NSString *subscriberIdentifier in self.statusCallbackMapTable.keyEnumerator.allObjects) {
            NSSet *callbacks = [self.statusCallbackMapTable objectForKey:subscriberIdentifier];
            for (DownloadStatusCallback callback in callbacks) {
                callback(status);
            }
        }
        if (status == ZGCacheStatus_finished) {
//            self.observedFile = nil;
//            [ZGCacheDataBase updateDownloadFile:self.observedFile];
        }
    } else if ([keyPath isEqualToString:@"downloadProgress"]) {
        float progress = [change[NSKeyValueChangeNewKey] floatValue];
        for (NSString *subscriberIdentifier in self.progressMapTable.keyEnumerator.allObjects) {
            NSSet *callbacks = [self.progressMapTable objectForKey:subscriberIdentifier];
            for (DownloadProgressCallback callback in callbacks) {
                callback(progress);
            }
        }
    }
}

- (void)setObservedFile:(ZGCachableFile *)observedFile{
    if (_observedFile != observedFile) {
        
        [_observedFile removeObserver:self forKeyPath:@"downloadProgress"];
        [_observedFile removeObserver:self forKeyPath:@"downloadStatus"];
        
        _observedFile = observedFile;
        
        [observedFile addObserver:self forKeyPath:@"downloadProgress" options:NSKeyValueObservingOptionNew context:nil];
        [observedFile addObserver:self forKeyPath:@"downloadStatus" options:NSKeyValueObservingOptionNew context:nil];
        
        LTDeallocNotifier *notifier = [[LTDeallocNotifier alloc] init];
        
        __weak typeof(self) weakSelf = self;
        __weak typeof(observedFile) weakObserveFile = observedFile;
        notifier.deallocBlock = ^{
            __strong typeof(weakObserveFile) strongObserveFile = weakObserveFile;
            [strongObserveFile removeObserver:weakSelf forKeyPath:@"downloadProgress"];
            [strongObserveFile removeObserver:weakSelf forKeyPath:@"downloadStatus"];
        };
        observedFile.deallocNotifier = notifier;
    }
}

- (void)dealloc{
    self.observedFile = nil;
    NSLog(@"observer销毁了");
}

@end


@implementation NSObject(downloadObserve)

- (NSString *)subscriberIdentifier{
    NSString *identifier = objc_getAssociatedObject(self, _cmd);
    if (!identifier) {
        identifier = [NSString stringWithFormat:@"%@_%p",NSStringFromClass([self class]), self];
        objc_setAssociatedObject(self, _cmd, identifier, OBJC_ASSOCIATION_RETAIN);
    }
    return identifier;
}

- (void)setDeallocNotifier:(LTDeallocNotifier *)deallocNotifier{
    objc_setAssociatedObject(self, @selector(deallocNotifier), deallocNotifier, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (LTDeallocNotifier *)deallocNotifier{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)stopObserve{
    for (LTDownloadObserver *observer in observersMapTable.objectEnumerator.allObjects) {
        [observer removeSubscriberWithIdentifier:[self subscriberIdentifier]];
    }
}

//- (void)setInternalObserver:(LTDownloadObserver *)observer{
//   //内部observer（真正进行observe的是该downloadObserver）
//    //这里使用一个wrapper，实现对关联对象的weak引用
//    LTAssociateObjectWrapper *wrapper = [LTAssociateObjectWrapper new];
//    wrapper.associatedObj = observer;
//    objc_setAssociatedObject(self, @selector(internalObserver), wrapper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
//}
//
//- (LTDownloadObserver *)internalObserver{
//    LTAssociateObjectWrapper *wrapper = objc_getAssociatedObject(self, _cmd);
//    return wrapper.associatedObj;
//}

- (void)observeDownloadFileOfID:(NSString *)fileID withStatusCallback:(DownloadStatusCallback)statusCallback progressCallback:(DownloadProgressCallback)progressCallback speedCallback:(DownloadSpeedCallback)speedCallback{

    [self observeDownloadFileOfID:fileID withStatusCallback:statusCallback progressCallback:progressCallback speedCallback:speedCallback handleError:nil];
}

- (void)observeDownloadFileOfID:(NSString *)fileID
         withStatusCallback:(DownloadStatusCallback _Nullable)statusCallback
           progressCallback:(DownloadProgressCallback _Nullable)progressCallback
              speedCallback:(DownloadSpeedCallback _Nullable)speedCallback
                handleError:(DownloadErrorHandle _Nullable)errorHandle{
    //TODO:这里不使用self直接监听file，因为有两个问题不好处理：1.用self监听的话，就要需要强引用上面几个callback，这样外部往往在调用时没注意使用weakself,导致泄漏；2.监听者需要在dealloc时让被监听者移除掉自己，而分类中直接重写dealloc方法，会导致各种问题，所以暂时用下面使用一个全局字典的方式处理
    LTDownloadObserver *observer = [LTDownloadObserver observerOfFileID:fileID];
    
    [observer addSubscriberWithKey:[self subscriberIdentifier]
                              statusCallback:statusCallback
                            progressCallback:progressCallback
                               speedCallback:speedCallback
                                 handleError:errorHandle];
    
    //主动触发一次KVO
    ZGCachableFile *info = [[ZGDownloadManager sharedManager] managedFileOfID:fileID];
    if (statusCallback) {
        statusCallback(info.downloadStatus);
    }
    
    if (progressCallback) {
        progressCallback(info.downloadProgress);
    }
}

- (void)stopObserveDownloadFileOfID:(NSString *)fileID{
    LTDownloadObserver *observer = [observersMapTable objectForKey:fileID];
    [observer removeSubscriberWithIdentifier:[self subscriberIdentifier]];
}

+ (void)observersOfFile:(ZGCachableFile *)file shouldUpdateDownloadSpeed:(CGFloat)speed{
    LTDownloadObserver *observer = [observersMapTable objectForKey:file.fileID];
    for (NSString *subscriberIdentifier in observer.speedCallbackMapTable.keyEnumerator.allObjects) {
        NSSet *callbacks = [observer.speedCallbackMapTable objectForKey:subscriberIdentifier];
        for (DownloadSpeedCallback callback in callbacks) {
            callback(speed);
        }
    }
}

+ (void)observersOfFile:(ZGCachableFile *)file shouldDisposeError:(NSError *)error{
    LTDownloadObserver *observer = [observersMapTable objectForKey:file.fileID];
    for (NSString *subscriberIdentifier in observer.speedCallbackMapTable.keyEnumerator.allObjects) {
        NSSet *handles = [observer.errorHanldes objectForKey:subscriberIdentifier];
        for (DownloadErrorHandle handle in handles) {
            handle(error);
        }
    }
}

@end
