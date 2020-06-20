//
//  Bonjour.h
//  audioTest
//
//  Created by yogi on 6/20/20.
//  Copyright © 2020 zed. All rights reserved.
//

#ifndef Bonjour_h
#define Bonjour_h

@interface Bonjour : NSObject

//publish a given fakePK at a ConnectPoing
+(void)publish:(NSString *)serviceTypeBonjour pkType:(int)pkType pk:(NSString *)pk host:(NSString *)host port:(int)port
        result:(void (^)(NSDictionary<NSString *, NSNumber *> *errorDict))result;

+(void)startSearch:(NSString *)serviceTypeBonjour
result:(void (^)(NSDictionary<NSString *, NSNumber *> *errorDict))result;


//start searching Services, and notify the caller to connect
//stop searching
+(void)stopSearch:(NSString *)serviceTypeBonjour;

@end



#endif /* Bonjour_h */
