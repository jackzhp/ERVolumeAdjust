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


/*

 - (void)openStreams
 {
     assert(self.inputStream != nil);            // streams must exist but aren't open
     assert(self.outputStream != nil);
     assert(self.streamOpenCount == 0);
     
     [self.inputStream  setDelegate:self];
     [self.inputStream  scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
     [self.inputStream  open];
     
     [self.outputStream setDelegate:self];
     [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
     [self.outputStream open];
 }

 - (void)closeStreams
 {
     assert( (self.inputStream != nil) == (self.outputStream != nil) );      // should either have both or neither
     if (self.inputStream != nil) {
         [self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
         [self.inputStream close];
         self.inputStream = nil;
         
         [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
         [self.outputStream close];
         self.outputStream = nil;
     }
     self.streamOpenCount = 0;
 }

 - (void)send:(NSData *)msg {//  (uint8_t)message
 //    assert(self.streamOpenCount == 2);
     
     
     NSError *error;
         // Only write to the stream if it has space available, otherwise we might block.
         // In a real app you have to handle this case properly but in this sample code it's
         // OK to ignore it; if the stream stops transferring data the user is going to have
         // to tap a lot before we fill up our stream buffer (-:
         
         if ( [self.outputStream hasSpaceAvailable] ) {
             NSInteger   bytesWritten;
             bytesWritten = [self.outputStream write:msg.bytes maxLength:msg.length];
             if (bytesWritten != msg.length) {
                 //            [self setupForNewGame];
                 NSLog(@"write bytes:%ld != %lu",(long)bytesWritten,(unsigned long)msg.length);
             }
         }
 }

 */
