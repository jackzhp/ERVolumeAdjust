//
//  UpLoader.h
//  audioTest
//
//  Created by yogi on 6/15/20.
//  Copyright © 2020 zed. All rights reserved.
//

#ifndef UpLoader_h
#define UpLoader_h

@protocol UpLoaderUser<NSObject>
@optional
-(void)onProgress:(int)ID progress:(int)progress;
-(void)onEnded:(int)ID ireason:(int)ireason sreason:(NSString *)sreason;

@end

@interface UpLoader : NSObject

//+(void)upload:(NSString *)pathFile url:(NSString *)url;
+(int)upload:(NSString *)pathFile url:(NSString *)url user:(id<UpLoaderUser> )user;
+(void)cancel:(int)ID;


@end



#endif /* UpLoader_h */
