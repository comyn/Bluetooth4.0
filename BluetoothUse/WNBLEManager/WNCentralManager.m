//
//  WNCentralManager.m
//  BluetoothUse
//
//  Created by comyn on 2018/4/12.
//  Copyright © 2018年 comyn. All rights reserved.
//

#import "WNCentralManager.h"
#import <CoreBluetooth/CoreBluetooth.h>

NSString * const SERVICE_UUID = @"SERVICE_UUID";
NSString * const CHARACTERISTIC_UUID = @"CHARACTERISTIC_UUID";
NSString * const CHARACTERISTIC_UUID_READ = @"CHARACTERISTIC_UUID_READ";
NSString * const CHARACTERISTIC_UUID_WRITE = @"CHARACTERISTIC_UUID_WRITE";

@interface WNCentralManager () <CBCentralManagerDelegate, CBPeripheralDelegate>
// 蓝牙设备中心管理对象
@property (nonatomic, strong) CBCentralManager *centralManager;
// 存储保存发现的外设设备
@property (nonatomic, strong) NSMutableArray *peripherals;
// 连接成功的外设
@property (nonatomic, strong) CBPeripheral *peripheral;
//保存的特征
@property (nonatomic, strong) CBCharacteristic *writeCharacteristic;

@property (nonatomic, copy) ScanBLESuccess scanBLESuccess;
@property (nonatomic, copy) ScanBLEFailure scanBLEFailure;
@property (nonatomic, assign) BOOL keepConnectState;
@end

@implementation WNCentralManager

- (NSMutableArray *)peripherals {
    if (!_peripherals) {
        _peripherals = [NSMutableArray new];
    }
    return _peripherals;
}

+ (instancetype)shareInstance {
    static WNCentralManager *wnCentralManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!wnCentralManager) {
            wnCentralManager = [[self alloc] init];
        }
    });
    return wnCentralManager;
}

- (instancetype)init {
    if (self = [super init]) {
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
    }
    return self;
}

#pragma mark - 初始化中心管理者便会触发此代理方法，管理状态更新检测，只有状态为on的时候才可以开启扫描，否则出错

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state != CBCentralManagerStatePoweredOn) {
        [self.centralManager stopScan];
        self.scanBLEFailure ? self.scanBLEFailure(@"设置-蓝牙-开启") : nil;
        return;
    }
    //如果蓝牙开启，扫描外设，扫描到外设自动调用代理方法
    [self.centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerRestoredStateScanOptionsKey:@(YES)}];//options恢复状态扫描为YES，没有规定具体服务就是所有扫描所有设备
}

#pragma mark - 扫描到外部设备后出发，多次调用

-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI{
    NSLog(@"当扫描到设备:%@",peripheral.name);
    if (![self.peripherals containsObject:peripheral]) {
        //缓存下来
        [self.peripherals addObject:peripheral];
        self.scanBLESuccess ? self.scanBLESuccess(self.peripherals.copy) : nil;
    }
}

#pragma mark - 连接外设成功

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    // 可以停止扫描
    [self.centralManager stopScan];
    NSLog(@"连接到外设名称为（%@）的设备-成功",peripheral.name);
    self.peripheral = peripheral;
    // 外设设置代理
    self.peripheral.delegate = self;
    // 外设发现服务
    [peripheral discoverServices:nil];
    // 根据UUID来寻找服务,如果这里匹配了服务，下面的代理就只有一个服务了
//    [peripheral discoverServices:@[[CBUUID UUIDWithString:@"SERVICE_UUID"]]];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(updateConnectState:)]) {
        [self.delegate updateConnectState:WNBLEStateConnected];
    }
}

#pragma mark - 连接外设失败

-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(updateConnectState:)]) {
        [self.delegate updateConnectState:WNBLEStateFailure];
    }
}

#pragma mark - 外设断开连接

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    if (self.keepConnectState) {
        [self.centralManager connectPeripheral:self.peripheral options:nil];
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(updateConnectState:)]) {
        [self.delegate updateConnectState:WNBLEStateDisConect];
    }
}

#pragma mark - CBPeripheralDelegate 外设找到服务

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    if (error)
    {
        NSLog(@"外设扫描服务错误：Discovered services for %@ with error: %@", peripheral.name, [error localizedDescription]);
        return;
    }
    for (CBService *service in peripheral.services) {
        //匹配指定的服务，去发现服务特征
        if ([service.UUID.UUIDString isEqualToString:SERVICE_UUID]) {
            // 执行方法，自动调用找到特征代理方法
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

#pragma mark - 找到特征方法

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    if (error)
    {
        NSLog(@"扫描特征出错：error Discovered characteristics for %@ with error: %@", service.UUID, [error localizedDescription]);
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        NSLog(@"服务:%@ 的 特征: %@",service.UUID,characteristic.UUID.UUIDString);
    }
    
    for (CBCharacteristic *characteristic in service.characteristics){
        {
            //读特征处理，根据UUID匹配对应特征，读取一次性属性，名称、电量。方法不常用
            if ([characteristic.UUID.UUIDString isEqualToString:CHARACTERISTIC_UUID_READ]) {
                // 执行方法，自动调用读取更新特征值代理方法
                [peripheral readValueForCharacteristic:characteristic];
            }
            //写特征处理，根据UUID匹配对应特征，向外设发送指令，写失败，设置回调type，查看原因
            if ([characteristic.UUID.UUIDString isEqualToString:CHARACTERISTIC_UUID_WRITE]) {
                NSLog(@"处理写特征");
                //只有 characteristic.properties 有write的权限才可以写
                if(characteristic.properties & CBCharacteristicPropertyWrite){
                    /*
                     最好一个type参数可以为CBCharacteristicWriteWithResponse或type:CBCharacteristicWriteWithResponse,区别是是否会有反馈
                     */
                    //向外设发送0001命令
                    NSData *data = [@"0001" dataUsingEncoding:NSUTF8StringEncoding];
                    [self.peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
                    self.writeCharacteristic = characteristic;
                }else{
                    NSLog(@"该字段不可写！");
                }
            }
            // -------- 订阅特征的处理(监听，持续接收?) --------，监听成功后，Notify属性值会为YES,可以用来判断是否监听成功
            if ([characteristic.UUID.UUIDString isEqual:CHARACTERISTIC_UUID])
            {
                NSLog(@"处理了订阅特征");
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            }
        }
    }
}

// 写特征CBCharacteristicWriteWithResponse的数据写入的结果回调
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"数据写入失败: %@", error);
    } else {
        NSLog(@"数据写入成功");//写入成功后，立即回调读取？
        [peripheral readValueForCharacteristic:characteristic];
    }
}

//获取外设发来的数据，不论是read和notify,获取数据都是从这个方法中读取

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_READ]])
    {
        //控制器去处理
        if (self.delegate && [self.delegate respondsToSelector:@selector(receivedValue:)])
        {
            [self.delegate receivedValue:characteristic.value.copy];
        }
    }
    //打印出characteristic的UUID和值
    //!注意，value的类型是NSData，具体开发时，会根据外设协议制定的方式去解析数据
    NSLog(@"特征 uuid:%@  value:%@",characteristic.UUID,characteristic.value);
}

// 订阅特征的值改变时触发的回调
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"订阅失败");
        NSLog(@"%@",error);
    }
    if (characteristic.isNotifying) {
        NSLog(@"订阅成功");
    } else {
        NSLog(@"取消订阅");
    }
}

//外部方法

- (void)scanBLE:(ScanBLESuccess)success failure:(ScanBLEFailure)failure {
    self.scanBLESuccess = success;
    self.scanBLEFailure = failure;
}

- (void)connectPeripheralWith:(NSString *)name {
    [self.peripherals enumerateObjectsUsingBlock:^(CBPeripheral *peripheral, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([peripheral.name isEqualToString:name]) {
            [self.centralManager connectPeripheral:peripheral options:nil];
        }
    }];
}

//停止扫描并断开连接
- (void)disconnect {
    //断开连接
    if (self.peripheral) {
        [self.centralManager cancelPeripheralConnection:self.peripheral];
    }
}

//读数据
- (void)readFromPeripheral
{
    NSLog(@"读数据");
    [self.peripheral readValueForCharacteristic:self.writeCharacteristic];
}

//写数据
- (void)writeToPeripheralWith:(NSData *)data
{
    NSLog(@"写数据");
    [self.peripheral writeValue:data forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithoutResponse];
}

//监听数据
- (void)notifyPeripheral
{
    NSLog(@"监听数据");
    [self.peripheral setNotifyValue:YES forCharacteristic:self.writeCharacteristic];
}

- (void)keepConnect:(BOOL)state {
    self.keepConnectState = state;
}
//取消通知
-(void)cancelNotifyCharacteristic:(CBPeripheral *)peripheral
                   characteristic:(CBCharacteristic *)characteristic{
    
    [peripheral setNotifyValue:NO forCharacteristic:characteristic];
}
@end
