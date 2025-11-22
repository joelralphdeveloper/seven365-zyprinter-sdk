//
//  PosWIFIManager.m
//  Printer
//
//  Created by ding on 2022/12/23
//

#import "POSWIFIManager.h"
#import "GCD/GCDAsyncSocket.h"
#import <SystemConfiguration/CaptiveNetwork.h>

static POSWIFIManager *shareManager = nil;

@interface POSWIFIManager ()<GCDAsyncSocketDelegate>
// 连接的socket对象
@property (nonatomic,strong) GCDAsyncSocket *sendSocket;
@property (nonatomic,strong) NSTimer *connectTimer;
@end

@implementation POSWIFIManager

/// Create WiFi management object
+ (instancetype)shareWifiManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareManager = [[POSWIFIManager alloc] init];
    });
    return shareManager;
}

- (instancetype)init {
    if (self = [super init]) {
        dispatch_queue_t queue = dispatch_queue_create([@"com.label.print" UTF8String], DISPATCH_QUEUE_SERIAL);
        _sendSocket=[[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:queue];
        _sendSocket.userData = SocketOfflineByServer;
        _commandBuffer=[[NSMutableArray alloc]init];
    }
    return self;
}
//连接wifi打印机
-(bool)ConnectWifiPrinter:(NSString *)ip port:(UInt16)port{
    if(!_isConnected){
        NSError *err = nil;
        _isFirstRece=true;
        _isReceivedData=false;
        _isConnected=false;
        _isConnected=[_sendSocket connectToHost:ip onPort:port withTimeout:-1 error:&err];
        if(!_isConnected){
            _isConnected=false;
            NSLog(@"connect failed\n");
        }else{
            _isConnected=true;
            //NSLog(@"connect success\n");
        }
        NSDate* tmpStartData = [NSDate date];
        while(_isFirstRece){
            double timeout = [[NSDate date] timeIntervalSinceDate:tmpStartData];
            if(timeout>2){//连接超时
                _isConnected=false;
                NSLog(@"connect timeout,connect failed\n");
                break;
            }
        }
        if(!_isFirstRece){
            _isConnected=true;
            NSLog(@"didconnect,connect success\n");
        }
    }
    return _isConnected;
}
/**
 Disconnect manually
 */
- (void)POSDisConnect {
    
    if (_sendSocket) {
        _isAutoDisconnect = NO;
        [self.connectTimer invalidate];
        [_sendSocket disconnect];
    }
}


/// send data
/// @param data data
-(void)POSWriteCommandWithData:(NSData *)data{
    if (_connectOK) {
         //NSLog(@"----%@",data);
        if (commandSendMode==0){
            [_sendSocket writeData:data withTimeout:-1 tag:0];
           
        }
        else{
            [_commandBuffer addObject: data];
//            [_sendSocket writeData:data withTimeout:-1 tag:0];
        }
    }

    
}

/// Send data and call back
/// @param data data
/// @param block callback
-(void)POSWriteCommandWithData:(NSData *)data withResponse:(POSWIFICallBackBlock)block{

    if (_connectOK) {
        self.callBackBlock = block;
        if (commandSendMode==0)
            [_sendSocket writeData:data withTimeout:-1 tag:0];
        else
            [_commandBuffer addObject: data];
        //[_sendSocket writeData:data withTimeout:-1 tag:0];
    }

}

/**
send messages
 @param str data
 */
- (void)POSSendMSGWith:(NSString *)str {
    if (_connectOK) {
        str = [str stringByAppendingString:@"\r\n"];
        NSData *data = [str dataUsingEncoding:NSASCIIStringEncoding];
        NSLog(@"%@==%@",str,data);
        if (commandSendMode==0)
       [_sendSocket writeData:data withTimeout:-1 tag:0];
        else
        [_commandBuffer addObject: data];
       
    }
}
//
///**
//    发送POS指令
// */
//- (void)PosWritePOSCommandWithData:(NSData *)data withResponse:(PosWIFICallBackBlock)block {
//    if (_connectOK) {
//        self.callBackBlock = block;
//        if (commandSendMode==0)
//            [_sendSocket writeData:data withTimeout:-1 tag:0];
//        else
//            [_commandBuffer addObject: data];
//        //[_sendSocket writeData:data withTimeout:-1 tag:0];
//    }
//}

/// Connect the printer
/// @param hostStr Printer ip address
/// @param port port of printer
/// @param block callback
-(void)POSConnectWithHost:(NSString *)hostStr port:(UInt16)port completion:(POSWIFIBlock)block
{
    _connectOK = NO;
    _hostStr = hostStr;
    _port = port;
    
    NSError *error=nil;
    _isConnected=false;
    _connectOK=[self ConnectWifiPrinter:hostStr port:port];
    block(_connectOK);
}

/// Connection established
/// @param sock sock object
/// @param host Host address
/// @param port The port number
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    if(sock.isConnected){
        NSLog(@"didconnect to host");
        _isConnected=true;
        _isFirstRece=false;
    }
    if ([self.delegate respondsToSelector:@selector(POSWIFIManager:didConnectedToHost:port:)]) {
        [self.delegate POSWIFIManager:self didConnectedToHost:host port:port];
    }
    [_sendSocket readDataWithTimeout: -1 tag: 0];
}
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    if(sock.isDisconnected){
        _isConnected=false;
    }
    NSLog(@"%s %d, tag = %ld", __FUNCTION__, __LINE__, tag);
    if ([self.delegate respondsToSelector:@selector(POSWIFIManager:didWriteDataWithTag:)]) {
        [self.delegate POSWIFIManager:self didWriteDataWithTag:tag];
    }
    [_sendSocket readDataWithTimeout: -1 tag: 0];
}
- (void)socket:(GCDAsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
    _isAutoDisconnect = YES;
    if ([self.delegate respondsToSelector:@selector(POSWIFIManager:willDisconnectWithError:)]) {
        [self.delegate POSWIFIManager:self willDisconnectWithError:err];
    }
    NSLog(@"%s %d, tag = %@", __FUNCTION__, __LINE__, err);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    
    NSString *msg = [[NSString alloc] initWithData: data encoding:NSUTF8StringEncoding];
    
    if ([self.delegate respondsToSelector:@selector(POSWIFIManager:didReadData:tag:)]) {
        [self.delegate POSWIFIManager:self didReadData:data tag:tag];
    }
    NSLog(@"%@", data);
    [_sendSocket readDataWithTimeout: -1 tag: 0];
}
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err{
    if(sock.isDisconnected){
        _isConnected=false;
       // NSLog(@"printer disconnected");
    }
    _connectOK = NO;
    if ([self.delegate respondsToSelector:@selector(POSWIFIManagerDidDisconnected:)]) {
        [self.delegate POSWIFIManagerDidDisconnected:self];
    }
}
- (void)showAlert:(NSString *)str {
    UIAlertView *alter = [[UIAlertView alloc] initWithTitle:@"提示" message:str delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
    [alter show];
}



-(NSArray*)POSGetBuffer
{
    return [_commandBuffer copy];
}

-(void)POSClearBuffer
{
    [_commandBuffer removeAllObjects];
}

-(void)sendCommand:(NSData *)data
{
    [_sendSocket writeData:data withTimeout:-1 tag:0];
}

-(void)POSSendCommandBuffer
{
    float timeInterver=0.5;
 
    for (int t=0;t<[_commandBuffer count];t++)
    {
        //[self performSelectorOnMainThread:@selector(sendCommand:) withObject:_commandBuffer[t] waitUntilDone:NO ];
        [self performSelector:@selector(sendCommand:) withObject:_commandBuffer[t] afterDelay:timeInterver];
        timeInterver=timeInterver+0.2;
    }
    [_commandBuffer removeAllObjects];
}

- (void)POSSetCommandMode:(BOOL)Mode{
    commandSendMode=Mode;
}


@end
