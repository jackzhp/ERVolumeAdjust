//
//  UpLoader.m
//  audioTest
//
//  Created by yogi on 6/15/20.
//  Copyright © 2020 zed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UpLoader.h"
#import "TUSData.h"
#import "TUSResumableUpload.h"

static int IDnext=1;
static TUSResumableUpload *task;

@implementation UpLoader

+(int)upload:(NSString *)pathFile url:(NSString *)url user:(id<UpLoaderUser>)user{
    
   NSString * urlBase=@"http://192.168.254.138:8080/Receiver/"; //with ending "/"   files/
//    if(task){
//        task=nil;
//    }

    //    NSError *error;
    NSString *fingerprint=@"fingerprint"; //TODO: how should I set fingerprint? it is just a kind of ID, so sha256 is good.
    task=//[[TUSResumableUpload alloc]initWithURL:urlBase path:pathFile fingerprint:fingerprint];
    [TUSResumableUpload task:urlBase path:pathFile fingerprint:fingerprint];
    task.ID=IDnext++;

    task.failureBlock=^(NSError *error){
        [user onEnded:task.ID ireason:-1 sreason:error.localizedFailureReason];
    };
    task.progressBlock=^(NSInteger sent, NSInteger total){
        float r=sent;
        r/=total; r*=100;
        [user onProgress:task.ID progress:(int)r];
    };
    task.resultBlock=^(NSURL *fileURL){
        NSLog(@"result block is called:%@",fileURL.absoluteString);
        [user onEnded:task.ID ireason:0 sreason:nil];
    };
    dispatch_async(dispatch_get_main_queue(),^{
        [task start];
    });
    return task.ID;
}

+(void)cancel:(int)ID{
    
}

-(void)onInited:(int)ID{
    
}
-(void)onProgress:(int)ID progress:(int)progress{
    
}
-(void)onEnded:(int)ID ireason:(int)ireason sreason:(NSString *)sreason{
    
}




@end
