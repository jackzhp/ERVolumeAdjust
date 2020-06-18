//
//  TUSResumableUpload.h
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^TUSUploadResultBlock)(NSURL* fileURL);
typedef void (^TUSUploadFailureBlock)(NSError* error);
typedef void (^TUSUploadProgressBlock)(NSInteger bytesWritten, NSInteger bytesTotal);

typedef struct _TUSRange {
    long long first;
    long long last;
} TUSRange;

NS_INLINE TUSRange TUSMakeRange(long long first, long long last) {
    TUSRange r;
    r.first = first;
    r.last = last;
    return r;
}

//NS_ENUM(long long, TUSRangeBytes) {TUSInvalidRange = -1};
#define TUSInvalidRange  -1

@class TUSData;

@interface TUSResumableUpload : NSObject 

@property (readwrite, copy) TUSUploadResultBlock resultBlock;
@property (readwrite, copy) TUSUploadFailureBlock failureBlock;
@property (readwrite, copy) TUSUploadProgressBlock progressBlock;
@property (readwrite) int ID;

//- (id)initWithURL:(NSString *)url data:(TUSData *)data fingerprint:(NSString *)fingerprint;
//- (id)initWithURL:(NSString *)urlBase path:(NSString *)pathFile fingerprint:(NSString *)fingerprint;
+(TUSResumableUpload *)task:(NSString *)urlBase path:(NSString *)pathFile fingerprint:(NSString *)fingerprint;
-(void)set:(int) fake data:(TUSData *)data;
- (void) start;
+ (NSMutableDictionary*)resumableUploads;

- (TUSRange)rangeFromHeader:(NSString*)rangeHeader;

-(void)onStreamError://(TUSData *)data error:
(NSError *)error;
-(void)onDataSent;//:(TUSData *)data;

/* if we sent 1 byte, then this increase 1.
 this is not the offset of this chunk of data in the big file.
 */
@property (assign) long long offsetToSend;

//@property (nonatomic,weak) TUSResumableUpload *upload;
//@property (readwrite,copy) void (^failureBlock)(NSError* error);
//@property (readwrite,copy) void (^successBlock)(void);

//- (id)initWithData:(NSData*)data;
//- (id)initWithData:(NSData*)data upload:(TUSResumableUpload *)upload;
- (NSInputStream*)dataStream;
- (long long)sizeFile;
- (void)stop;


@end