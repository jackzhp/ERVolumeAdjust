//
//  SocketStream.m
//  audioTest
//
//  Created by yogi on 5/28/20.
//  Copyright © 2020 zed. All rights reserved.
//

#import "SocketStreams.h"
#import "AVsimple.h"

static NSMutableDictionary<NSString *,SocketStreams *> *sss=nil;


@implementation SocketStreams {

    
    //the following is used to receive file
    long fileSizeRecvTotal;
    long fileSizeRecv; //received
    BOOL receivingFile;
    uint8_t bufRecv[1024];
    int istartRecv,iendRecv;
    
    
    //the following is used to send file
    BOOL sendingFile;
    NSInteger fileSizeSend;
    NSRange rangeNext;
    uint8_t bufSend[4096];
    int istartSend, iendSend;
    //    NSInputStream *isFile;
}

+(NSMutableDictionary<NSString *,SocketStreams *> *)all{
    return sss;
}

-(SocketStreams *)init{
    self=[super init];
    if(self){
        //        _dir=nil;
        _av=nil;
        _isConnected=NO;
        
        receivingFile=NO;
        istartRecv=iendRecv=0;
        
        sendingFile=NO;
        istartSend=iendSend=0;
        
        _tag=nil;
        _isNet=nil;
        _osNet=nil;
        _fnRecv=nil;
        _osFile=nil;
        _dataFile=nil;
        _fnSend=nil;

    }
    return self;
}


+(SocketStreams *)for_m:(NSString *)key{
    if(sss){}else{ sss=[[NSMutableDictionary alloc]init];
        //        [sss retain];
    }
    SocketStreams *ss;
    if(ss){}else{
        ss=[[SocketStreams alloc]init];
        ss.tag=key;
        sss[key]=ss;
    }
    return ss;
}


//NSString *host=@"192.168.254.139";
//int port=11223;
-(void)connect:(NSString *)host port:(int)port{
    self.isConnected=YES;
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (__bridge CFStringRef _Null_unspecified)host, port, &readStream, &writeStream);
    //how to retain them?
    [self onStreams:readStream os:writeStream];
}
-(void)onConnected:(CFSocketNativeHandle)sock{
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, sock, &readStream, &writeStream);
    [self onStreams:readStream os:writeStream];
}
-(void)onStreams:(CFReadStreamRef)is os:(CFWriteStreamRef)os{
    self.isNet =CFBridgingRelease(is);
    self.isNet.delegate=self;
    [self.isNet scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.isNet open];

    self.osNet =CFBridgingRelease(os); // (__bridge_transfer NSOutputStream *)writeStream;
    self.osNet.delegate=self;
    [self.osNet scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.osNet open];
}
//@protocol NSStreamDelegate <NSObject>
//@optional
- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode{
    switch(eventCode) {
        case NSStreamEventNone: {
            NSLog(@"none: remote:%@",stream);
            break;
        }
        case NSStreamEventOpenCompleted: {
            NSLog(@"open complete:%@:%@",self,stream);
            break;
        }
        case NSStreamEventHasBytesAvailable: {
            if(stream==self.isNet) {}else{
                NSLog(@"%@(not %@) has bytes",stream,self.isNet);
            }
            NSInputStream *is=self.isNet; //(NSInputStream *)stream;
            BOOL continueReceive=YES;
            while(continueReceive){
                if([is hasBytesAvailable]){
                    int len =(int) [is read:bufRecv+iendRecv maxLength:(int)(sizeof(bufRecv)-iendRecv)];
                    //positive, 0, -1
                    if(len==0){
                        NSLog(@"unexpected len:0");
                        //TODO: close stream
                    }else if(len==-1){
                        NSLog(@"unexpected error:%@",is.streamError);
                        //TODO: close stream
                    }else if(len>0){
                        iendRecv+=len;
                        while(istartRecv<iendRecv){
                            if(receivingFile){
                                //TODO: write what we received to file
                                int len=iendRecv-istartRecv; //TODO: is it ok to redefine len?
                                int lenE=(int)(fileSizeRecvTotal-fileSizeRecv);
                                int lenWrite=len>=lenE?lenE:len;
                                int lenWritten=(int)[self.osFile write:bufRecv+istartRecv maxLength:lenWrite]; //why return -1???
                                if(lenWritten==0){
                                    NSLog(@"write 0 bytes to file");
                                    //TODO: terminate the stream
                                }else if(lenWritten<0){
                                    NSLog(@"failed to write:%@",self.osFile.streamError);
                                    //TODO: terminate stream
                                }else { //ret>0
                                    fileSizeRecv+=lenWrite;
                                    istartRecv+=lenWrite;
                                    if(lenWritten<lenWrite){
                                        NSLog(@"not all data saved to file");
                                        continueReceive=NO; //since we have data not saved yet.
                                        //TODO: I need a mechanism to be notified when more space is available.
                                        break;
                                    }
                                    if(fileSizeRecv>=fileSizeRecvTotal){
                                        [self onReceived];
                                    }
                                }
                            }else{
                                [self recvFile_meta];//TODO: read the message, and update istart
                            }
                            //                    [_data appendBytes:(const void *)buf length:len];
                            //                    // bytesRead is an instance variable of type NSNumber.
                            //                    [bytesRead setIntValue:[bytesRead intValue]+len];
                        } //process the date we already have
                        if(istartRecv==iendRecv){
                            istartRecv=iendRecv=0;
                        }
                    }else{
                        NSLog(@"unexpected len:%d",len);
                        //close the stream
                    }
                }else break;
            } //readIfAvailable
            break;
        }
        case NSStreamEventErrorOccurred: {
            //TODO: terminate stream
            NSLog(@"error for %@:%@",stream, stream.streamError);
            break;
        }
        case NSStreamEventEndEncountered:{
            [self terminateStream:stream];
            break;
        }
        case NSStreamEventHasSpaceAvailable: {
            while(self.osNet.hasSpaceAvailable){ //with this loop, we might send too fast, the receiver or the routers might have to throw away data.
                if(istartSend==iendSend){
                    if(sendingFile){
                        istartSend=iendSend=0;
                        if(rangeNext.length>0){
                            [self.dataFile getBytes:bufSend range:rangeNext];
                            iendSend=(int)rangeNext.length;
                            NSUInteger start=rangeNext.location+rangeNext.length;
                            NSUInteger len=fileSizeSend-start;
                            rangeNext=NSMakeRange(start,len);
                        }else{
                            [self onSent];
                            break;
                        }
                    }else break;
                }
                if(istartSend<iendSend){
                    int len=(int)[self.osNet write:bufSend+istartSend maxLength:iendSend-istartSend];
                    if(len<0){
                        NSLog(@"error on write to remote:%@",self.osNet.streamError);
                        //TODO: terminate os
                    }else if(len==0){
                        NSLog(@"write 0 bytes to remote");
                        //TODO: terminate os
                    }else{
                        istartSend+=len;
                        if(istartSend == iendSend && sendingFile==NO){ //meta has been sent
                            sendingFile=YES;
                        }
                    }
                }
            }
            break;
        }
            // continued
    }
}



//the following is used to receive

//@protocol NSStreamDelegate <NSObject>
//@optional

-(void)terminateStream:(NSStream *)stream{
    if(stream ==self.isNet){
        [self.isNet close];
        [self.isNet removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.isNet = nil; // stream is ivar, so reinit it
    }else if(stream ==self.osNet){
        [self.osNet close];
        [self.osNet removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.osNet = nil; // stream is ivar, so reinit it
    }else{
        NSLog(@"which stream:%@ %@ %@",stream, self.isNet, self.osNet);
    }
}





//the following is used to send

-(void)sendFile_meta{
    NSMutableData *data=[[NSMutableData alloc]init];
    uint64_t theInt = htonll(fileSizeSend);
    [data appendBytes:&theInt length:sizeof(theInt)];
    NSData *dataFileName=[self.fnSend dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t lenFN=dataFileName.length;
    [data appendBytes:&lenFN length:1];
    [data appendData:dataFileName];
    [data getBytes:bufSend length:data.length];
    istartSend=0;
    iendSend=(int)data.length;
    NSInteger len=sizeof(bufSend);
    if(fileSizeSend<len){
        len=fileSizeSend;
    }
    rangeNext=NSMakeRange(0, len);
    [self stream:self.osNet handleEvent:NSStreamEventHasSpaceAvailable];
}

-(void)recvFile_meta{
    uint8_t *p=bufRecv+istartRecv;
    uint64_t *pLen=(uint64_t *)p;
    long size=ntohll(*pLen); //the order is not right,
    p+=8;
    uint8_t n=*p;
    p++;
    //    if(p<bufRecv+sizeof(bufRecv)){
    //        *(p+n)=0;
    //    }
    self.fnRecv = [[NSString alloc] initWithBytes:p length:n encoding:NSUTF8StringEncoding];
    //exists? how much has been received, now we always receive from 0. unless we have info to indicate the starting point.
    NSString *path=[NSString stringWithFormat:@"%@%@.m4a",self.av.dir,self.fnRecv];
    self.fnRecv=path.lastPathComponent;
    NSLog(@"will save to file:%@",path); //exc_bad_access(code=1,...)
    long startPoint=0;
    BOOL append=startPoint>0;
    self.osFile=[[NSOutputStream alloc]initToFileAtPath:path append:append];
    [self.osFile open];
    if(startPoint>0){
        //fileSizeRecv=0;  from the file
        //TODO: fileSize  //if not from beginning then get the file size
        if(startPoint>fileSizeRecv){
            //some data is mising, we have to reject it.
            //TODO: terminate the stream
        }else if(startPoint==fileSizeRecv){
            
        }else{
            //TODO: we have to truncate some data.
        }
    }
    fileSizeRecvTotal=size;
    //if we have enough data for the message, read the message, and then update istart
    if(false){
        //if we do not have enough data and istart!=0, let's move the data to buf head to make istart=0
        iendRecv-=istartRecv;
        memmove(bufRecv,bufRecv+istartRecv,iendRecv);
        istartRecv=0;
    }else{ p+=n; istartRecv=(int)(p-bufRecv);
        receivingFile=YES;
    }
}

//if we have many, we need a queue.
-(void)sendFile:(NSString *)path { //TODO: rename to prepareToSend
    NSLog(@"will send file %@",path);
    NSFileManager *fm=[NSFileManager defaultManager];
    if([fm fileExistsAtPath:path]){
        NSError *error;
        self.dataFile=[NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:&error];
        if(self.dataFile){
            NSDictionary *attr=[fm attributesOfItemAtPath:path error:&error];
            if(attr){
                fileSizeSend=(int)[attr fileSize];
                self.fnSend=[path lastPathComponent];// stringByDeletingPathExtension];
                [self sendFile_meta];
            }
        }else{
            NSLog(@"error on open input file:%@",error);
        }
    }else{
        NSLog(@"can not find input file %@",path);
    }
    
}
-(void)onSent{
    sendingFile=NO;
    self.dataFile=nil;
    
}
-(void)onReceived{
    receivingFile=NO;
    [self.osFile close];
    [self.osFile removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode]; //do I need this?
//#ifdef MRC
//    [osFile release];
//#endif
    self.osFile = nil; // stream is ivar, so reinit it
    NSLog(@"received %@",self.fnRecv);
//    dispatch_async(dispatch_get_main_queue(), ^{
        [self.av play:self.fnRecv startPoint:0]; // autoStart:YES
//    });
}



@end
