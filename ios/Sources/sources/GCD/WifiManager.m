//
//  WifiManager.m
//  Printer
//
//  Created by ding on 2021/12/14.
//  Copyright © 2021 Admin. All rights reserved.
//

#import "WifiManager.h"

static WifiManager *shareManager = nil;
@interface WifiManager ()<GCDAsyncSocketDelegate,BLEManagerDelegate>
//connected wifi socket object
@property (nonatomic,strong) GCDAsyncSocket *wifiPrinter;
@property (nonatomic,strong) GCDAsyncSocket *wifiPrinterMonitor;
//ble printer object
@property (nonatomic,strong) BLEManager *blePrinter;
@end
@implementation WifiManager
+ (instancetype)shareManager:(int)printerType threadID:(NSString*)thread{
    shareManager = [[WifiManager alloc] init:printerType threadID:thread];
    return shareManager;
}

- (instancetype)init:(int)printerType threadID:(NSString*)thread{
    if (self = [super init]) {
        _isConnected=false;
        _printerType=printerType;
        _printerStatus=Disconnected;
        _printSucceed=false;
        _monitorPort=9100;
        _printPort=9100;
        _isAutoRecon=false;
        _isFirstRece=true;
        _isReceivedData=false;
        _isNewPrinter=false;
        switch (printerType) {
            case WifiPrinter:
            {
                dispatch_queue_t queue = dispatch_queue_create([thread UTF8String], DISPATCH_QUEUE_SERIAL);
                _wifiPrinter=[[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:queue];
                if(_monitorPort==4000){
                    dispatch_queue_t queue2 = dispatch_queue_create("com.printer.monitor", DISPATCH_QUEUE_SERIAL);
                    _wifiPrinterMonitor=[[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:queue2];
                }
            }
                break;
            case BlePrinter:
            {

            }
                break;
            default:
                break;
        }
    }
    return self;
}
-(bool)ConnectWifiPrinter:(NSString *)ip port:(UInt16)port{
    if(!_isConnected){
        _ip=ip;
        _port=port;
        NSError *err = nil;
        _isFirstRece=true;
        _isUserDiscon=false;
        _isReceivedData=false;
        _isNewPrinter=false;
        _isConnected=[_wifiPrinter connectToHost:ip onPort:port withTimeout:-1 error:&err];
        if(!_isConnected){
            _isConnected=false;
            _printerStatus=Disconnected;
            _isUserDiscon=true;
            NSLog(@"connect failed\n");
        }else{
            _isConnected=true;
            //NSLog(@"connect success\n");
            _printerStatus=Normal;
        }
        if(_monitorPort==4000&&_isConnected){
            [_wifiPrinterMonitor connectToHost:ip onPort:4000 error:&err];
        }
        NSDate* tmpStartData = [NSDate date];
        while(_isFirstRece){
            double timeout = [[NSDate date] timeIntervalSinceDate:tmpStartData];
            if(timeout>2){//connect timeout
                _isConnected=false;
                _printerStatus=Disconnected;
                _isUserDiscon=true;
                NSLog(@"connect timeout,connect failed\n");
                break;
            }
        }
        if(!_isFirstRece){
            _isConnected=true;
            NSLog(@"didconnect,connect success\n");
            _printerStatus=Normal;
            [self exitForbidPrinting];
        }
    }
    return _isConnected;
}
-(void)StartMonitor{
    //Turn on the function of avoiding lost orders, send monitoring commands, and obtain the status of the printer through the timer
    //Set a timer to execute the OnclickStart method regularly
    //The timer needs to be added to the current sub-thread
   _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(ReadDataFromPrinter) userInfo:nil repeats:YES];
    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
   // [runloop addTimer:_timer forMode:NSDefaultRunLoopMode];
    [runloop addTimer:_timer forMode:NSRunLoopCommonModes];
    if(_monitorPort==_printPort&&_isConnected){
        //free lost order,It needs to be set once, restarting the printer will take effect
        Byte free[]={0x1B, 0x73, 0x42, 0x45, 0x92, 0x9A, 0x01, 0x00, 0x5F, 0x0A};
        //9100 port monitor cmd
        Byte b[]={0x1d,0x61,0x1f};
        [_wifiPrinter writeData:[[NSData alloc]initWithBytes:b length:3] withTimeout:-1 tag:1];
        //2022/7/5 DING Added the function of getting the firmware version
        //NSLog(@"Get the printer firmware version");
        [_wifiPrinter writeData:[self GetFirmwareVersion] withTimeout:-1 tag:2];
        [_wifiPrinter readDataWithTimeout:-1 tag:2];
    }
    [runloop run];
}
-(NSData*)exitForbidPrinting{
    Byte exitForbidPrinting[]={0x1b,0x41};//Exit the print prohibition state
    return [[NSData alloc] initWithBytes:exitForbidPrinting length:sizeof(exitForbidPrinting)];
}
-(void)freeLostOrder{
    Byte freeLostOrder[]={0x1B, 0x73, 0x42, 0x45, 0x92, 0x9A, 0x01, 0x00, 0x5F, 0x0A};//No Lost Order Order
    [_wifiPrinter writeData:[[NSData alloc]initWithBytes:freeLostOrder length:freeLostOrder] withTimeout:-1 tag:0];
}
-(bool)ReconWifiPrinter:(NSString *)ip port:(UInt16)port{
    if(!_isConnected){
        _ip=ip;
        _port=port;
        NSError *err = nil;
        _isFirstRece=true;
        _isConnected=[_wifiPrinter connectToHost:ip onPort:port withTimeout:-1 error:&err];
        if(!_isConnected){
            _isConnected=false;
            _printerStatus=Disconnected;
            //NSLog(@"connect failed\n");
        }else{
            _isConnected=true;
            //NSLog(@"connect success\n");
            _printerStatus=Normal;
        }
    }
    return _isConnected;
}
//connect ble printer
-(void)ConnectBlePrinter:(CBPeripheral *)peripheral{

}
//Disconnect the printer
- (void)DisConnectPrinter{
    NSLog(@"disconnect printer");
    _isUserDiscon=true;
    switch (_printerType) {
        case WifiPrinter:
        {
            [_wifiPrinter disconnect];
        }
            break;
        case BlePrinter:
        {

        }
            break;
        default:
            break;
    }
}
//send data to printer
-(bool)SendReceiptToPrinter:(NSData *)data{
    switch (_printerType) {
        case WifiPrinter:
        {
            //Differentiate the printing process of old and new printers, and the old printers do not perform status query processing
            _printSucceed=false;
            if(_isNewPrinter){//New machine delivery process
                if((_printerStatus==Normal||_printerStatus==PrintCompleted)&&_isConnected){
                    NSMutableData* dataM=[[NSMutableData alloc] init];
                    Byte init[]={0x1b,0x40};
                    [dataM appendBytes:init length:sizeof(init)];
                    [dataM appendData:data];
                    Byte cutPaper[]={0x1D,0x56,0x42,0x00,0x0A,0x0A,0x00};//The paper cutting instruction needs to be before the order instruction
                    Byte b[]={0x1D,0x28,0x48,0x06,0x00,0x30,0x30,0x30,0x30,0x30,0x31};//The order number will be returned to the client after printing the data
                    [dataM appendBytes:cutPaper length:sizeof(cutPaper)];
                    [dataM appendBytes:b length:sizeof(b)];
                    [_wifiPrinter writeData:dataM withTimeout:-1 tag:0];
                    NSDate* tmpStartData = [NSDate date];
                    while(!_printSucceed){
                        double timeout = [[NSDate date] timeIntervalSinceDate:tmpStartData];
                        if(timeout>60||_printerStatus==CoverOpened||_printerStatus==NoPaper||_printerStatus==Error||_printerStatus==Disconnected){//Print data timeout, the default is 1 minute; printing fails in error conditions
                            Byte exitForbidPrinting[]={0x1b,0x41};//Exit the print prohibition state
                                                           [_wifiPrinter writeData:[[NSData alloc]initWithBytes:exitForbidPrinting length:2] withTimeout:-1 tag:0];
                            NSLog(@"timeout,cost time = %f seconds", timeout);
                            _printSucceed=false;
                            if (_printerStatus==Normal) {
                                _isConnected=false;
                                _printerStatus=Disconnected;
                            }
                            break;
                        }
                    }
                }else{
                    Byte exitForbidPrinting[]={0x1b,0x41};//Exit the print prohibition state
                                                   [_wifiPrinter writeData:[[NSData alloc]initWithBytes:exitForbidPrinting length:2] withTimeout:-1 tag:0];
                    _printSucceed=false;
                    NSLog(@"Printer status %@\n",[self statusToString:_printerStatus]);
                }
            }else{
                [self SendDataToPrinter:data];
            }
        }
            break;
        case BlePrinter:
        {

        }
            break;
        default:
            break;
    }
    return _printSucceed;
}
//Old machine sending process
-(bool)SendDataToPrinter:(NSData *)data{
    switch (_printerType) {
        case WifiPrinter:
        {
            _printSucceed=true;
            if((_printerStatus==Normal)&&_isConnected){
                //NSMutableData* dataM=[[NSMutableData alloc] initWithData:data];
                //[_wifiPrinter writeData:dataM withTimeout:-1 tag:0];
                NSMutableData* dataM=[[NSMutableData alloc] init];
                Byte init[]={0x1b,0x40};
                [dataM appendBytes:init length:sizeof(init)];
                [dataM appendData:data];
                Byte cutPaper[]={0x1D,0x56,0x42,0x00,0x0A,0x0A,0x00};
                [dataM appendBytes:cutPaper length:sizeof(cutPaper)];
                [_wifiPrinter writeData:dataM withTimeout:-1 tag:0];
                NSDate* tmpStartData = [NSDate date];
                while(!_isReceivedData){
                    double timeout = [[NSDate date] timeIntervalSinceDate:tmpStartData];
                    if(timeout>3||_printerStatus==CoverOpened||_printerStatus==NoPaper||_printerStatus==Error||_printerStatus==Disconnected){//Print data timeout, the default is 3 seconds; printing failed in error condition
                        Byte exitForbidPrinting[]={0x1b,0x41};//Exit the print prohibition state
                                                       [_wifiPrinter writeData:[[NSData alloc]initWithBytes:exitForbidPrinting length:sizeof(exitForbidPrinting)] withTimeout:-1 tag:0];
                        NSLog(@"timeout,cost time = %f seconds", timeout);
                        _printSucceed=false;
                        if (_printerStatus==Normal) {
                            _isConnected=false;
                            _printerStatus=Disconnected;
                        }
                        break;
                    }
                }
            }else{
                Byte exitForbidPrinting[]={0x1b,0x41};//Exit the print prohibition state
                                               [_wifiPrinter writeData:[[NSData alloc]initWithBytes:exitForbidPrinting length:sizeof(exitForbidPrinting)] withTimeout:-1 tag:0];
                _printSucceed=false;
                NSLog(@"Printer status %@\n",[self statusToString:_printerStatus]);
            }
        }
            break;
        case BlePrinter:
        {

        }
            break;
        default:
            break;
    }
    return _printSucceed;
}
//Read the data returned by the printer
-(void)ReadDataFromPrinter{
    _receivedData=nil;
    if(_monitorPort==4000){
        //4000 port monitoring command needs to be sent every time the printer status is read
        Byte b[]={0x1b,0x76};
        [_wifiPrinterMonitor writeData:[[NSData alloc]initWithBytes:b length:2] withTimeout:-1 tag:1];
        //Call the read function and return via didread
        [_wifiPrinterMonitor readDataWithTimeout:-1 tag:1];
    }else{
        //Call the read function and return via didread
        [_wifiPrinter readDataWithTimeout:-1 tag:1];
    }
}
//Get the current status of the printer
-(NSString*)GetPrinterStatus{
    if(!_isReceivedData){
        _printerStatus=Error;
    }
    return [self statusToString:_printerStatus];
}
//Whether the printing is complete or not
-(BOOL)IsPrintCompletely{
    return false;
}
//printer status string
- (NSString*)statusToString:(PrinterStatus)printerStatus {
    NSString *result = nil;
    switch(printerStatus) {
        case Normal:
            result = @"Normal";
            break;
        case Error:
            result = @"Error";
            break;
        case Printing:
            result = @"Printing";
            break;
        case Busy:
            result = @"Busy";
            break;
        case CashDrawerOpened:
            result = @"CashDrawerOpened";
            break;
        case CoverOpened:
            result = @"CoverOpened";
            break;
        case PaperNearEnd:
            result = @"PaperNearEnd";
            break;
        case NoPaper:
            result = @"NoPaper";
            break;
        case CutPaper:
            result = @"CutPaper";
            break;
        case FeedPaper:
            result = @"FeedPaper";
            break;
        case PrintCompleted:
            result=@"PrintCompleted";
            break;
        case Disconnected:
            result=@"Printer Disconnected";
            break;
        default:
            [NSException raise:NSGenericException format:@"Unexpected status."];
    }

    return result;
}
//2022/7/5 DING Get the firmware version of the printer Only port 9100 is valid
-(NSData*)GetFirmwareVersion{
    Byte data[] = {0x1d,0x49,0xd9};
    return [[NSData alloc] initWithBytes:data length:sizeof(data)];
}
#pragma mark wifi
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    if(sock.isConnected){
        //NSLog(@"didconnect to host");
        _isConnected=true;
        _printerStatus=Normal;
        _isFirstRece=false;
    }
}
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    if(sock.connectedPort==_monitorPort||sock.connectedPort==_printPort){
        NSLog(@"data=%@,tag=%ld", data,tag);
        _receivedData=data;
        _isReceivedData=true;
        Byte b[data.length];
        bool printCompelte=false;
        Byte jobID[]={0x37,0x22,0x30,0x30,0x30,0x31,0x00};
        for (int i = 0 ; i < data.length; i++) {
            NSData *idata = [data subdataWithRange:NSMakeRange(i, 1)];
            b[i] =((Byte*)[idata bytes])[0];
        }
        //The order number of the printer may be returned together with the status, so it is necessary to judge the substring more accurately
        for(int i=0,j=0;i<data.length&&data.length>=7&&j<sizeof(jobID);i++){
            if(b[i]==jobID[j]){
                j++;
                if(j==sizeof(jobID)){
                    printCompelte=true;
                    _printSucceed=true;
                    _printerStatus=PrintCompleted;
                }
            }
        }
        if(data.length>=29){//Get the firmware version of the printer
            //First remove the order number and status value that may be included in the string
            NSString* printerInfo=[[NSString alloc] initWithData: [data subdataWithRange:NSMakeRange(data.length-29,29)] encoding:NSASCIIStringEncoding];
            NSString* printerDate=[printerInfo substringToIndex:6];
            if(printerDate!=nil && [printerDate compare:@"220401"]!=NSOrderedAscending){//2022.4.01  after
                //NSLog(@"Printers after 2022.4.01");
                _isNewPrinter=true;
            }else{
                //NSLog(@"Printers before 2022.4.01");
                _isNewPrinter=false;
            }
        }
        if(data.length==4){
            //0x1400602f cant print
            Byte nomralBytes[]={0x14,0x00,0x00,0x0f};
            if(data.bytes==nomralBytes){
                _printerStatus=Normal;
            }
            else{
                //first byte
                if ((b[0] & (0x04)) != 0) {//cash
                    _printerStatus=CashDrawerOpened;
                    _printerStatus=Normal;
                } else {
                    //n
                }
                if ((b[0] & (0x08)) != 0) {// busy
                    _printerStatus=Busy;
                } else {
                    //n
                }
                if ((b[0] & (0x20)) != 0) { // cover
                    _printerStatus=CoverOpened;
                } else {
                    //n
                }
                if (((b[0] & (0x40)) != 0)){//feedpaper
                    _printerStatus=FeedPaper;
                } else {
                    //n
                }
                //second byte
                if ((b[1] & (0x08)) != 0) {//cutpaper
                    _printerStatus=CutPaper;
                    NSLog(@"Printer status %@\n",[self statusToString:_printerStatus]);
                } else {
                    //n
                }
                if ((b[1] & (0x20)) != 0) {//fatal
                    _printerStatus=Error;
                } else {
                    //n
                }
                if ((b[1] & (0x40)) != 0) {//autorestor
                    //y
                } else {
                    //n
                }

                //third byte
                if ((b[2] & (0x03)) != 0) {//papernearend
                    _printerStatus=PaperNearEnd;
                } else {
                    //n
                }

                if ((b[2] & (0x0C)) != 0) {//nopaper
                    _printerStatus=NoPaper;
                } else {
                    //n
                }

                if ((b[2] & (0x40)) != 0) {//printpaper
                    _printerStatus=Printing;
                    _printerStatus=Normal;
                } else {
                    //n
                }
            }
        }

    }
}
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    if(sock.isDisconnected){
        _isConnected=false;
        _printerStatus=Disconnected;
    }
}
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err{
    if(sock.isDisconnected){
        _isConnected=false;
        _printerStatus=Disconnected;
       // NSLog(@"printer disconnected");
        if(_isAutoRecon&&!_isUserDiscon){
            //Do not repeat if reconnection fails
            _isAutoRecon=[self ReconWifiPrinter:_ip port:_port];
            if(_isAutoRecon){
                //NSLog(@"reconnect success");
            }else{
                NSLog(@"reconnect failed,check printer ip or power");
            }
        }
    }
}
#pragma mark ble
- (void)BLEManagerDelegate:(BLEManager *)BLEmanager connectPeripheral:(CBPeripheral *)peripheral {

}

- (void)BLEManagerDelegate:(BLEManager *)BLEmanager didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {

}

- (void)BLEManagerDelegate:(BLEManager *)BLEmanager didWriteValueForCharacteristic:(CBCharacteristic *)character error:(NSError *)error {

}

- (void)BLEManagerDelegate:(BLEManager *)BLEmanager disconnectPeripheral:(CBPeripheral *)peripheral isAutoDisconnect:(BOOL)isAutoDisconnect {

}

- (void)BLEManagerDelegate:(BLEManager *)BLEmanager updatePeripheralList:(NSArray *)peripherals RSSIList:(NSArray *)RSSIArr {

}

@end
