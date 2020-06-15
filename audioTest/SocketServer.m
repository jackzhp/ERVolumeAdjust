//
//  SocketServer.m
//  audioTest
//
//  Created by yogi on 5/28/20.
//  Copyright © 2020 zed. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#import "SocketServer.h"
#import "SocketStreams.h"

static AVsimple* avh;

void SocketServerIncoming(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info){
    NSData *dataIn=(__bridge NSData *)(address);
    //    uint8_t *buf=malloc(add.length);
    //    [add getBytes:buf range:NSMakeRange(0, add.length)];
    struct sockaddr_in  *socketAddress = nil;
    socketAddress = (struct sockaddr_in *)[dataIn bytes];
    NSString *ipString = [NSString stringWithFormat: @"%s", inet_ntoa(socketAddress->sin_addr)];
    NSLog(@"incoming from remote:%@",ipString);
    if(type==kCFSocketAcceptCallBack){}else{
        NSLog(@"type %lu",type);
    }
    
    //CFSocketError CFSocketSendData(CFSocketRef s, CFDataRef address, CFDataRef data, CFTimeInterval timeout);
    
    const CFSocketNativeHandle *sock=(CFSocketNativeHandle *)data;
    
    //   CFStreamCreatePairWithSocket(kCFAllocatorDefault, *sock, CFReadStreamRef  _Null_unspecified *readStream, CFWriteStreamRef  _Null_unspecified *writeStream);
    SocketStreams *ss=[SocketStreams for_m:ipString];
    if(ss.isConnected){}else{
        ss.av=avh;
        [ss onConnected:*sock];
    }
}


@implementation  SocketServer


+(void)listen:(BOOL)ip4 ip:(NSString *)ip_s port:(int)port av:(AVsimple *)av{
    avh=av;
    CFSocketRef mycfsock;
    if(ip4){
        mycfsock = CFSocketCreate(kCFAllocatorDefault,PF_INET,SOCK_STREAM,IPPROTO_TCP,
                                  kCFSocketAcceptCallBack, SocketServerIncoming, NULL);
        struct sockaddr_in sin;
        memset(&sin, 0, sizeof(sin));
        sin.sin_len = sizeof(sin);
        sin.sin_family = AF_INET; /* Address family */
        sin.sin_port =htons(port); //0;//port;// htons(0); /* Or a specific port */
        const char *ip_s_c=[ip_s UTF8String];
        sin.sin_addr.s_addr= inet_addr(ip_s_c);//INADDR_ANY; // use any, it is OK, though sometimes failed. use ip_s_c is also good.
        CFDataRef sincfd = CFDataCreate(kCFAllocatorDefault,(UInt8 *)&sin,sizeof(sin));
        CFSocketSetAddress(mycfsock, sincfd);
        CFRelease(sincfd); NSLog(@"listening at %@ on %d",ip_s,port);
    }else{
        mycfsock = CFSocketCreate(kCFAllocatorDefault,PF_INET6,SOCK_STREAM,IPPROTO_TCP,
                                  kCFSocketAcceptCallBack, SocketServerIncoming, NULL);
        struct sockaddr_in6 sin6;
        memset(&sin6, 0, sizeof(sin6));
        sin6.sin6_len = sizeof(sin6);
        sin6.sin6_family = AF_INET6; /* Address family */
        sin6.sin6_port = htons(0); /* Or a specific port */
        sin6.sin6_addr = in6addr_any;
        CFDataRef sin6cfd = CFDataCreate(kCFAllocatorDefault,(UInt8 *)&sin6,sizeof(sin6));
        CFSocketSetAddress(mycfsock, sin6cfd);
        CFRelease(sin6cfd);
    }
    CFRunLoopSourceRef socketsource = CFSocketCreateRunLoopSource(kCFAllocatorDefault,mycfsock,0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(),socketsource,kCFRunLoopDefaultMode);
    CFRelease(socketsource);
}


@end


