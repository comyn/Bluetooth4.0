//
//  WNPeripheralManager.m
//  BluetoothUse
//
//  Created by comyn on 2018/4/12.
//  Copyright © 2018年 comyn. All rights reserved.
//

#import "WNPeripheralManager.h"
#import <CoreBluetooth/CoreBluetooth.h>

//NSString * const SERVICE_UUID = @"SERVICE_UUID";
//NSString * const CHARACTERISTIC_UUID = @"CHARACTERISTIC_UUID";
//NSString * const CHARACTERISTIC_UUID_READ = @"CHARACTERISTIC_UUID_READ";
//NSString * const CHARACTERISTIC_UUID_WRITE = @"CHARACTERISTIC_UUID_WRITE";
@interface WNPeripheralManager () <CBPeripheralManagerDelegate>

@property (nonatomic, strong) CBPeripheralManager *peripheralManager;
@property (nonatomic, strong) CBMutableCharacteristic *characteristic;
@property (nonatomic, copy) UpdateStateBlock updateStateBlock;
@end

@implementation WNPeripheralManager

+ (instancetype)shareInstance {
    static WNPeripheralManager *wnPeripheralManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wnPeripheralManager = [[self alloc] init];
    });
    return wnPeripheralManager;
}

- (instancetype)init {
    if (self = [super init]) {
        // 创建外设管理器，会回调peripheralManagerDidUpdateState方法
        self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];

    }
    return self;
}
- (void)getUpdateState:(UpdateStateBlock)block {
    self.updateStateBlock = block;
}
/*
 设备的蓝牙状态
 CBManagerStateUnknown = 0,  未知
 CBManagerStateResetting,    重置中
 CBManagerStateUnsupported,  不支持
 CBManagerStateUnauthorized, 未验证
 CBManagerStatePoweredOff,   未启动
 CBManagerStatePoweredOn,    可用
 */
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    if(self.updateStateBlock) {
        self.updateStateBlock(peripheral.state);
    }

    if (peripheral.state != CBPeripheralManagerStatePoweredOn) {
        return;
    }
    // 创建Service（服务）和Characteristics（特征）
    [self setupServiceAndCharacteristics];
    // 根据服务的UUID开始广播
    [self.peripheralManager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey:@[[CBUUID UUIDWithString:@"SERVICE_UUID"]]}];
}

/** 创建服务和特征 */
- (void)setupServiceAndCharacteristics {
    // 创建服务
    CBUUID *serviceID = [CBUUID UUIDWithString:@"SERVICE_UUID"];
    CBMutableService *service = [[CBMutableService alloc] initWithType:serviceID primary:YES];
    // 创建服务中的特征
    CBUUID *characteristicID = [CBUUID UUIDWithString:@"CHARACTERISTIC_UUID"];
    CBMutableCharacteristic *characteristic = [
                                               [CBMutableCharacteristic alloc]
                                               initWithType:characteristicID
                                               properties:
                                               CBCharacteristicPropertyRead |
                                               CBCharacteristicPropertyWrite |
                                               CBCharacteristicPropertyNotify
                                               value:nil
                                               permissions:CBAttributePermissionsReadable |
                                               CBAttributePermissionsWriteable
                                               ];
    // 特征添加进服务
    service.characteristics = @[characteristic];
    // 服务加入管理
    [self.peripheralManager addService:service];
    
    // 为了手动给中心设备发送数据
    self.characteristic = characteristic;
}

/** 中心设备读取数据的时候回调 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request {
    // 请求中的数据，这里把文本框中的数据发给中心设备
    request.value = [self.data dataUsingEncoding:NSUTF8StringEncoding];
    // 成功响应请求
    [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
}

/** 通过固定的特征发送数据到中心设备 */
- (void)sendMsgToCentralManager:(id)parameter success:(void(^)(BOOL sendSuccess))success failure:(void(^)(NSString * errorDescription))failure {
    BOOL sendSuccess = [self.peripheralManager updateValue:[parameter dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.characteristic onSubscribedCentrals:nil];
    if (sendSuccess) {
        NSLog(@"数据发送成功");
        success ? success(sendSuccess) : nil;
    }else {
        NSLog(@"数据发送失败");
        if (!parameter) {
            failure ? failure(@"发送数据位空") : nil;
        }else{
            failure ? failure(@"发送失败") : nil;
        }
    }
}

/** 订阅成功回调 */
-(void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    NSLog(@"%s",__FUNCTION__);
}

/** 取消订阅回调 */
-(void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic {
    NSLog(@"%s",__FUNCTION__);
}

@end
