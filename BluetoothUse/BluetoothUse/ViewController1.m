//
//  ViewController1.m
//  BluetoothUse
//
//  Created by comyn on 2018/4/12.
//  Copyright © 2018年 comyn. All rights reserved.
//

#import "ViewController1.h"
#import "WNCentralManager.h"

@interface ViewController1 () <WNCentralManagerDelegate>

@end

@implementation ViewController1

- (void)viewDidLoad {
    [super viewDidLoad];
    [[WNCentralManager shareInstance] scanBLE:^(NSArray *bleList) {
        NSLog(@"bleList=%@",bleList);
    } failure:^(NSString *reason) {
        NSLog(@"reason=%@", reason);
    }];
}

- (void)updateConnectState:(NSInteger)state {
    
}

- (void)receivedValue:(NSData *)data {
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
