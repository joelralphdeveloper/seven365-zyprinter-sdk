//
//  PrinterManager.h
//  Printer
//
//  Created by ding on 2021/12/14.
//  Copyright © 2021 Admin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"
#import "BLEManager.h"
NS_ASSUME_NONNULL_BEGIN

@interface WifiManager : NSObject
#pragma mark
//PrinterType
typedef enum {
    WifiPrinter=0,
    BlePrinter
} PrinterType;
//PrinterStatus
typedef enum {
    Normal=0,
    Error,
    Printing,
    Busy,
    CashDrawerOpened,
    CoverOpened,
    PaperNearEnd,
    NoPaper,
    CutPaper,
    FeedPaper,
    PrintCompleted,
    Disconnected
} PrinterStatus;
//Printer IP
@property (nonatomic,copy) NSString *ip;
//Printer Port
@property (nonatomic,assign) UInt16 port;
//Connection Status
@property (nonatomic,assign) BOOL isConnected;
//Received data
@property(nonatomic,copy)NSData* receivedData;
//Whether the status of the printer is successfully monitored
@property (nonatomic,assign) BOOL isReceivedData;
//Printer Type
@property(nonatomic,assign)NSUInteger printerType;
//Printer Status
@property(nonatomic,assign)int printerStatus;
@property(strong,nonatomic) NSTimer *timer;
//Monitor Port
@property(nonatomic,assign)int monitorPort;
//Print Port
@property(nonatomic,assign)int printPort;
//Print Succeed
@property(nonatomic,assign)bool printSucceed;
//Whether to automatically reconnect
@property(nonatomic,assign)bool isAutoRecon;
//Whether the user actively disconnected
@property(nonatomic,assign)bool isUserDiscon;
@property(nonatomic,assign)bool isFirstRece;
//Whether it is a machine manufactured after 2022/3/28
@property(nonatomic,assign)bool isNewPrinter;
#pragma mark
//+ (instancetype)shareManager:(int)printerType;
+ (instancetype)shareManager:(int)printerType threadID:(NSString*)thread;
//connect wifi printer
-(bool)ConnectWifiPrinter:(NSString *)ip port:(UInt16)port;
//start printer monitor
-(void)StartMonitor;
//Exit the print prohibition state
-(NSData*)exitForbidPrinting;
//No Lost Order
-(void)freeLostOrder;
//connect ble printer
-(void)ConnectBlePrinter:(CBPeripheral *)peripheral;
//disconnect printer
- (void)DisConnectPrinter;
//send data to printer
-(bool)SendDataToPrinter:(NSData *)data;
//Send the receipt to the printer, and judge the status of the printer
-(bool)SendReceiptToPrinter:(NSData *)data;
//Read the data returned by the printer
-(void)ReadDataFromPrinter;
//Get the current status of the printer
-(NSString*)GetPrinterStatus;
//Whether the printing is complete or not
-(BOOL)IsPrintCompletely;
@end

NS_ASSUME_NONNULL_END
