//
//  HCKeepBGRunManager.h
//  BlockRedpag
//
//  Created by 何其灿 on 2018/10/28.
//  Copyright © 2018 Lixiaoqian. All rights reserved.
//  APP保活

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HCKeepBGRunManager : NSObject
+ (HCKeepBGRunManager *)shareManager;

/**
 开启后台运行
 */
- (void)startBGRun;

/**
 关闭后台运行
 */
- (void)stopBGRun;

@end

NS_ASSUME_NONNULL_END
