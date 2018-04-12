//
//  WNPeripheralManager.h
//  BluetoothUse
//
//  Created by comyn on 2018/4/12.
//  Copyright © 2018年 comyn. All rights reserved.
//

#import <Foundation/Foundation.h>

//extern NSString * const SERVICE_UUID;
//extern NSString * const CHARACTERISTIC_UUID;
//extern NSString * const CHARACTERISTIC_UUID_READ;
//extern NSString * const CHARACTERISTIC_UUID_WRITE;

typedef enum : NSUInteger {
    WNBluetoothStateUnknown = 0,  //未知
    WNBluetoothStateResetting,    //重置中
    WNBluetoothStateUnsupported,  //不支持
    WNBluetoothStateUnauthorized, //未验证
    WNBluetoothStatePoweredOff,   //未启动
    WNBluetoothStatePoweredOn,    //可用
} WNBluetoothState;

typedef void(^UpdateStateBlock)(NSUInteger state);

@interface WNPeripheralManager : NSObject
@property (nonatomic, assign) id data;


+ (instancetype)shareInstance;
- (void)getUpdateState:(UpdateStateBlock)block;

- (void)sendMsgToCentralManager:(id)parameter
                        success:(void(^)(BOOL sendSuccess))success
                        failure:(void(^)(NSString * errorDescription))failure;
@end
