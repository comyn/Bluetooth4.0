//
//  ViewController.m
//  BluetoothUse
//
//  Created by comyn on 2018/3/16.
//  Copyright © 2018年 comyn. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "WNPeripheralManager.h"

#define UUIDSTR_ISSC_PROPRIETARY_SERVICE @"180A"
#define  UUIDSTR_ISSC_TRANS_TX @"2A29"
#define  UUIDSTR_ISSC_TRANS_RX @"2A29"

@interface ViewController () <CBCentralManagerDelegate,CBPeripheralDelegate>

// 蓝牙设备管理对象，中心设备，扫描、连接外设
@property (nonatomic, strong) CBCentralManager *centralManager;
// 存储保存发现的外设设备
@property (nonatomic, strong) NSMutableArray *peripherals;
//连接的外设
@property (nonatomic, strong) CBPeripheral *peripheral;
//保存的特征
@property (nonatomic, strong) CBCharacteristic *writeDataCharacteristic;

@end

@implementation ViewController

- (NSMutableArray *)peripherals {
    if (!_peripherals) {
        _peripherals = [NSMutableArray new];
    }
    return _peripherals;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];// nil默认主线程：dispatch_get_main_queue()
    self.centralManager.delegate = self;
    
}
#pragma mark - 管理状态更新检测，只有状态为on的时候才可以开启扫描，否则出错

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
//            ios 10之后使用了 CBManagerStateUnknown
        case CBCentralManagerStateUnknown:
            NSLog(@"设备未知状态：CBManagerStateUnknown");
            break;
        case CBCentralManagerStateResetting:
            NSLog(@"设备重置状态：CBCentralManagerStateResetting");
            break;
        case CBCentralManagerStateUnsupported:
            NSLog(@"设备不支持状态：CBCentralManagerStateUnsupported");
            break;
        case CBCentralManagerStateUnauthorized:
            NSLog(@"设备未授权状态：CBCentralManagerStateUnauthorized");
            break;
        case CBCentralManagerStatePoweredOff:
            NSLog(@"设备关闭状态：CBCentralManagerStatePoweredOff");
            break;
        case CBCentralManagerStatePoweredOn:
            NSLog(@"设备开启状态：CBCentralManagerStatePoweredOn");
            //如果蓝牙开启，扫描外设，扫描到外设自动调用代理方法
            [self.centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerRestoredStateScanOptionsKey:@(YES)}];//options恢复状态扫描为YES，没有规定具体服务就是所有扫描所有设备
            break;
        default:
            break;
    }
}

#pragma mark - 扫描到外部设备后出发，多次调用

-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI{
    
    NSLog(@"当扫描到设备:%@",peripheral.name);
    if (![self.peripherals containsObject:peripheral]) {
        //缓存下来
        [self.peripherals addObject:peripheral];
        //主线成界面刷新
        if ([peripheral.name isEqualToString:@"PLK_BLE_415"]) {
            [self.centralManager connectPeripheral:peripheral options:nil];
        }
    }
}

#pragma mark - 界面操作连接指定的外设设备

- (void)connect:(CBPeripheral *)peripheral {
    peripheral = self.peripherals[0];
}
#pragma mark - 连接外设成功

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"连接到外设名称为（%@）的设备-成功",peripheral.name);
    self.peripheral = peripheral;
    // 外设设置代理
    self.peripheral.delegate = self;
    // 外设发现服务
    [peripheral discoverServices:nil];


}

#pragma mark - 连接外设失败

-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"连接到外设名称为（%@）的设备-失败,原因:%@",[peripheral name],[error localizedDescription]);
}

#pragma mark - 外设断开连接

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    NSLog(@"外设连接断开连接 %@: %@\n", [peripheral name], [error localizedDescription]);
    [self.centralManager connectPeripheral:self.peripheral options:nil];
}

#pragma mark - CBPeripheralDelegate 外设找到服务

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    if (error)
    {
        NSLog(@"外设扫描服务错误：Discovered services for %@ with error: %@", peripheral.name, [error localizedDescription]);
        return;
    }
    NSLog(@"找到外设的服务：%@",peripheral.services);
    for (CBService *service in peripheral.services) {
        NSLog(@"====%@------%@+++++++",service.UUID.UUIDString,self.peripheral.identifier);
        //匹配指定的服务，去发现服务特征
        if ([service.UUID.UUIDString isEqualToString:UUIDSTR_ISSC_PROPRIETARY_SERVICE]) {
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
            if ([characteristic.UUID.UUIDString isEqualToString:UUIDSTR_ISSC_TRANS_RX]) {
                // 执行方法，自动调用读取更新特征值代理方法
                [peripheral readValueForCharacteristic:characteristic];
            }
            //写特征处理，根据UUID匹配对应特征，向外设发送指令，写失败，设置回调type，查看原因
            if ([characteristic.UUID.UUIDString isEqualToString:UUIDSTR_ISSC_TRANS_TX]) {
                NSLog(@"处理写特征");
                //向外设发送0001命令
                NSData *data = [@"0001" dataUsingEncoding:NSUTF8StringEncoding];
                [self.peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
                self.writeDataCharacteristic = characteristic;
                
            }
            // -------- 订阅特征的处理(监听，持续接收?) --------，监听成功后，Notify属性值会为YES,可以用来判断是否监听成功
            if ([characteristic.UUID.UUIDString isEqual:@"订阅特征的UUID名称"])
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
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:UUIDSTR_ISSC_TRANS_TX]])
        
    {
        
        NSString*value = [NSString stringWithFormat:@"%@",characteristic.value];
        
        NSMutableString*macString = [[NSMutableString alloc]init];
        
        [macString appendString:[[value substringWithRange:NSMakeRange(16,2)]uppercaseString]];
        
        [macString appendString:@":"];
        
        [macString appendString:[[value substringWithRange:NSMakeRange(14,2)]uppercaseString]];
        
        [macString appendString:@":"];
        
        [macString appendString:[[value substringWithRange:NSMakeRange(12,2)]uppercaseString]];
        
        [macString appendString:@":"];
        
        [macString appendString:[[value substringWithRange:NSMakeRange(5,2)]uppercaseString]];
        
        [macString appendString:@":"];
        
        [macString appendString:[[value substringWithRange:NSMakeRange(3,2)]uppercaseString]];
        
        [macString appendString:@":"];
        
        [macString appendString:[[value substringWithRange:NSMakeRange(1,2)]uppercaseString]];
        
        NSLog(@"MAC地址是macString:%@",macString);
        
    }
//    180A 2A29
//    服务:FEE7 的 特征: FEC8
    //打印出characteristic的UUID和值
    //!注意，value的类型是NSData，具体开发时，会根据外设协议制定的方式去解析数据
    NSLog(@"特征 uuid:%@  value:%@",characteristic.UUID,characteristic.value);
}

// 订阅特征的值改变时触发的回调
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"订阅特征的值改变了 : %@", characteristic);
    NSLog(@"%@",characteristic.value);
}
 


#pragma mark 找到特征描述符号信息代理方法

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    
    //打印出Characteristic和他的Descriptors
    NSLog(@"特征 uuid:%@",characteristic.UUID);
    for (CBDescriptor *d in characteristic.descriptors) {
        NSLog(@"Descriptor uuid:%@",d.UUID);
    }
}

#pragma mark - 读取更新描述符号的值

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error{
    //打印出DescriptorsUUID 和value
    //这个descriptor都是对于characteristic的描述，一般都是字符串，所以这里我们转换成字符串去解析
    NSLog(@"characteristic uuid:%@  value:%@",[NSString stringWithFormat:@"%@",descriptor.UUID],descriptor.value);
}

//写数据
-(void)writeCharacteristic:(CBPeripheral *)peripheral
            characteristic:(CBCharacteristic *)characteristic
                     value:(NSData *)value{
    
    //打印出 characteristic 的权限，可以看到有很多种，这是一个NS_OPTIONS，就是可以同时用于好几个值，常见的有read，write，notify，indicate，知知道这几个基本就够用了，前连个是读写权限，后两个都是通知，两种不同的通知方式。
    
    NSLog(@"%lu", (unsigned long)characteristic.properties);
    
    //只有 characteristic.properties 有write的权限才可以写
    if(characteristic.properties & CBCharacteristicPropertyWrite){
        /*
         最好一个type参数可以为CBCharacteristicWriteWithResponse或type:CBCharacteristicWriteWithResponse,区别是是否会有反馈
         */
        [peripheral writeValue:value forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    }else{
        NSLog(@"该字段不可写！");
    }
}

//取消通知
-(void)cancelNotifyCharacteristic:(CBPeripheral *)peripheral
                   characteristic:(CBCharacteristic *)characteristic{
    
    [peripheral setNotifyValue:NO forCharacteristic:characteristic];
}

//停止扫描并断开连接
-(void)disconnectPeripheral:(CBCentralManager *)centralManager
                 peripheral:(CBPeripheral *)peripheral{
    //停止扫描
    [centralManager stopScan];
    //断开连接
    [centralManager cancelPeripheralConnection:peripheral];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
