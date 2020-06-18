//
//  SocketStreams.h
//  audioTest
//
//  Created by yogi on 5/28/20.
//  Copyright © 2020 zed. All rights reserved.
//

#ifndef SocketStreams_h
#define SocketStreams_h

#import <Foundation/Foundation.h>

@class AVsimple;
@interface SocketStreams : NSObject<NSStreamDelegate>
//@property (weak,nonatomic) NSString *dir; //if I have AVsimple, then I do not need this.
//this weak is OK too. but strong does not hurt.
@property (strong,nonatomic) AVsimple *av; //for temp.

@property BOOL isConnected;
@property (strong,nonatomic) NSString *tag;

//CFReadStreamRef readStream;
@property (strong,nonatomic) NSInputStream *isNet;
//CFWriteStreamRef writeStream;
@property (strong,nonatomic) NSOutputStream *osNet; //to remote

//the following is used to receive file
@property (strong,nonatomic) NSString *fnRecv;
@property (strong,nonatomic) NSOutputStream *osFile;
//the following is used to send file
@property (strong,nonatomic) NSData *dataFile;
@property (strong,nonatomic) NSString *fnSend;




+(NSMutableDictionary<NSString *,SocketStreams *> *)all;
+(SocketStreams *)for_m:(NSString *)ip;

-(void)connect:(NSString *)host port:(int)port;
-(void)onConnected:(CFSocketNativeHandle)sock;


-(void)sendFile:(NSString *)path;
@end


#endif /* SocketStreams_h */
