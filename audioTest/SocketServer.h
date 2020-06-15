//
//  SocketServer.h
//  audioTest
//
//  Created by yogi on 5/28/20.
//  Copyright © 2020 zed. All rights reserved.
//

#ifndef SocketServer_h
#define SocketServer_h

@class AVsimple;
@interface SocketServer : NSObject
+(void)listen:(BOOL)ip4 ip:(NSString *)ip_s port:(int)port av:(AVsimple *)av;

@end


#endif /* SocketServer_h */
