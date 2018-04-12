//
//  WNCentralManager.h
//  BluetoothUse
//
//  Created by comyn on 2018/4/12.
//  Copyright © 2018年 comyn. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const SERVICE_UUID;
extern NSString * const CHARACTERISTIC_UUID;
extern NSString * const CHARACTERISTIC_UUID_READ;
extern NSString * const CHARACTERISTIC_UUID_WRITE;

typedef void(^ScanBLESuccess)(NSArray *bleList);
typedef void(^ScanBLEFailure)(NSString *reason);

typedef enum : NSUInteger {
    WNBLEStateConnected,    //连接成功
    WNBLEStateDisConect,    //连接断开
    WNBLEStateFailure,      //连接失败
} WNBLEState;

@protocol WNCentralManagerDelegate <NSObject>
//检测蓝牙连接状态
- (void)updateConnectState:(NSInteger)state;
//收到的数据
- (void)receivedValue:(NSData *)data;
@end

@interface WNCentralManager : NSObject
@property (nonatomic, assign) id<WNCentralManagerDelegate> delegate;

+ (instancetype)shareInstance;

/**
 蓝牙外设扫描

 @param success 扫描成功返回一组蓝牙列表
 @param failure 扫描失败返回失败原因
 */
- (void)scanBLE:(ScanBLESuccess)success failure:(ScanBLEFailure)failure;

/**
 连接蓝牙

 @param name 蓝牙名称
 */
- (void)connectPeripheralWith:(NSString *)name;

- (void)disconnect;


/**
 设置保持断开后重连

 @param state 开关状态
 */
- (void)keepConnect:(BOOL)state;
//读数据
- (void)readFromPeripheral;
//写数据
- (void)writeToPeripheralWith:(NSData *)data;
//监听数据
- (void)notifyPeripheral;


@end
