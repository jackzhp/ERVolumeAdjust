//
//  TUSResumableUpload.m
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//

//#import "TUSKit.h"
//#import "TUSData.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#import <CommonCrypto/CommonDigest.h>
#import "TUSResumableUpload.h"
#import "NSData+Hex.h"

#define HTTP_PUT @"PUT"
#define HTTP_POST @"POST"
#define HTTP_HEAD @"HEAD"
#define HTTP_RANGE @"Range"
#define HTTP_LOCATION @"Location"
#define HTTP_CONTENT_RANGE @"Content-Range"
#define HTTP_BYTES_UNIT @"bytes"
#define HTTP_RANGE_EQUAL @"="
#define HTTP_RANGE_DASH @"-"
#define REQUEST_TIMEOUT 30
#define TUS_BUFSIZE (32*1024)


typedef NS_ENUM(NSInteger, TUSUploadState) {
    Idle,
    CheckingFile,
    CreatingFile,
    UploadingFile,
};

static NSURL *fileUploading=nil;
//static NSMutableDictionary<NSString *,NSString *> *uploads=nil; //just map from fingerprint to location. TODO: remove this one use ouploads instead.
static NSMutableDictionary<NSString *,TUSResumableUpload *> *ouploads=nil; //just map from urlBase+fingerprint to Object
static BOOL useNSData=false;



@interface TUSResumableUpload ()
@property (strong, nonatomic) NSData* data; //data contains the whole file.
//@property (strong, nonatomic) TUSData *data;
@property (strong, nonatomic) NSURL *endpoint; //the base url
//http://192.168.254.138:8080/Receiver/
@property (strong, nonatomic) NSURL *url; //the url to upload this file
//http://192.168.254.138:8080/Receiver/files/61d12f13_9e91_4185_ae9f_950b181c8383
@property (strong, nonatomic) NSString *pathFile;
//@property (strong, nonatomic) NSString *fingerprint;
@property (nonatomic) long long offset; //when is it set? the remote has received till this offset.
@property (nonatomic) TUSUploadState state;
@property (strong, nonatomic) void (^progress)(NSInteger bytesWritten, NSInteger bytesTotal);
@property (nonatomic) FILE *f;
@property (nonatomic) BOOL extraCheck;


@end

@interface HTTPitem: NSObject<NSURLConnectionDelegate,NSStreamDelegate>

//@property (nonatomic,weak, protected) TUSResumableUpload *upload;
//@property (nonatomic,weak) TUSResumableUpload *upload;
@property (readwrite,copy) void (^onError)(NSError* error);
@property (readwrite,copy) void (^onDone)(void);

@end

@implementation HTTPitem

#pragma mark - NSURLConnectionDelegate Protocol Delegate Methods
- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error {
    self.onError(error);
}

#pragma mark - NSURLConnectionDataDelegate Protocol Delegate Methods

// TODO: Add support to re-initialize dataStream
- (NSInputStream *)connection:(NSURLConnection *)connection
            needNewBodyStream:(NSURLRequest *)request
{
    NSLog(@"ERROR: connection requested new body stream, which is currently not supported");
    return nil;
}

//- (void)connection:(NSURLConnection *)connection
//didReceiveResponse:(NSURLResponse *)response
//{
//    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
//    NSDictionary *headers = [httpResponse allHeaderFields];
//    NSLog(@"response:%@",httpResponse);
//    switch([self state]) {
//            /* at first do checking, then if needed, we create it. TODO: check Tus-Resumable header.
//             Before this, I should send OPTIONS to gather some info about the server.
//             */
//        case CheckingFile: {
//            if (httpResponse.statusCode != 200) {
//                NSLog(@"Server responded with %ld. Restarting upload",
//                      httpResponse.statusCode);
//                [self createFile];
//                return;
//            }
//            NSString *rangeHeader = [headers valueForKey:HTTP_RANGE];
//            if (rangeHeader) {
//                TUSRange range = [self rangeFromHeader:rangeHeader];
//                [self setOffset:range.last];
//                NSLog(@"Resumable upload at %@ for %@ from %lld (%@)",
//                      [self url], [self fingerprint], self.offset, rangeHeader);
//            }
//            else {
//                NSLog(@"Restarting upload at %@ for %@", [self url], [self fingerprint]);
//            }
//            [self uploadFile];
//            break;
//        }
//        case CreatingFile: {
//            NSString *location = [headers valueForKey:HTTP_LOCATION];
//            if(location){
//                [self onLocationDetermined:location];
//            }else{ //no Location
//                //                NSString *version=[headers valueForKey:@"Tus-Resumable"];
//                NSError *error=[[NSError alloc]initWithDomain:@"Location is not found" code:-1 userInfo:headers];
//                [self connection:connection didFailWithError:error];
//            }
//            break;
//        }
//        case UploadingFile:{
//            /*
//             <NSHTTPURLResponse: 0x2808bff20> { URL: http://192.168.254.138:8080/Receiver/files/996d96b5_27e2_4f03_a3da_acf9a61d8301 } { Status Code: 204, Headers {
//             Connection =     (
//             "keep-alive"
//             );
//             Date =     (
//             "Tue, 16 Jun 2020 02:37:55 GMT"
//             );
//             "Keep-Alive" =     (
//             "timeout=20"
//             );
//             "Tus-Resumable" =     (
//             "1.0.0"
//             );
//             "Upload-Offset" =     (
//             31389
//             );
//             "X-Content-Type-Options" =     (
//             nosniff
//             );
//             } }
//             */
//            NSString *offset_s = [headers valueForKey:@"Upload-Offset"];
//            if(offset_s){
//                NSInteger offset=[offset_s integerValue];
//                NSInteger offsetStart=self.offset;
//
//                if(offset !=offsetStart){
//                    NSLog(@"we have sent the data, but offset:%ld is not right %lld yet",offset, offsetStart);
//                    //what to do?
//                    //whetever is missing we send more
//                }
//                self.offset=offset;
//                if(offset < self.sizeFile){
//                    [self uploadFile];
//                }
//            }else{ //no Location
//                //                NSString *version=[headers valueForKey:@"Tus-Resumable"];
//                NSError *error=[[NSError alloc]initWithDomain:@"Location is not found" code:-1 userInfo:headers];
//                [self connection:connection didFailWithError:error];
//            }
//
//            break;
//        }
//        case Idle:
//
//            break;
//        default:
//            break;
//    }
//}


@end
@interface HTTPitemCheckFile : HTTPitem
@property (readwrite,copy) void (^onCodeUnexpected)(long statusCode);
@property (readwrite,copy) void (^onOffset)(long long offset);
@property (nonatomic,strong) NSURLConnection *connection ;
@property (nonatomic,weak) TUSResumableUpload *upload ;
@end

@implementation HTTPitemCheckFile
-(HTTPitemCheckFile *)init:(TUSResumableUpload *)upload{
    self=[super init];
    if(self){
        self.upload=upload;
    }
    return self;
}
-(void)sendRequest{
    NSDictionary *headers = @{ //HTTP_CONTENT_RANGE: [self contentRangeWithSize:size],
        @"Tus-Resumable": @"1.0.0"
        //        ,
        //        @"Upload-Length": [NSString stringWithFormat:@"%lu",(unsigned long)size]
        //                                       ,
        //        @"Upload-Metadata": meta //@"filename d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg==,is_confidential" //is this useful? needed?
        //TODO: sha256, last modification date
        //  should also be sent when do checkFile
        //  and sha256 should become the ID and base64(fingerprint).
    } ;
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:_upload.url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:HTTP_HEAD];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    
}
- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSDictionary *headers = [httpResponse allHeaderFields];
    NSLog(@"response:%@",httpResponse);
    /*  412
     Connection =     (
     "keep-alive"
     );
     Date =     (
     "Thu, 18 Jun 2020 11:46:45 GMT"
     );
     "Keep-Alive" =     (
     "timeout=20"
     );
     "Transfer-Encoding" =     (
     chunked
     );
     "Tus-Resumable" =     (
     "1.0.0"
     );
     "X-Content-Type-Options" =     (
     nosniff
     );
     
     */
    /*
     "Cache-Control" =     (
     "no-store"
     );
     Connection =     (
     "keep-alive"
     );
     Date =     (
     "Fri, 19 Jun 2020 03:24:40 GMT"
     );
     "Keep-Alive" =     (
     "timeout=20"
     );
     Server =     (
     "Apache-Coyote/1.1"
     );
     "Tus-Resumable" =     (
     "1.0.0"
     );
     "Upload-Length" =     (
     74843
     );
     "Upload-Metadata" =     (
     "sha256 QTM4RDRCNkE4RDYwRUEwNUJEOUJEM0NDRkQzOEI0QzlFNjI3QjVEQzEzNEVFMEU1MTZCMzQ2NEZBRTUxNjQzMQ=="
     );
     "Upload-Offset" =     (
     74843
     );
     "X-Content-Type-Options" =     (
     nosniff
     );
     
     
     */
    if (httpResponse.statusCode != 200) { //either 200 or 404(NotFound) or 409(sha256 Conflict)
        self.onCodeUnexpected(httpResponse.statusCode);
    }else{
        NSString *length_s=headers[@"Upload-Length"];
        if(length_s){
            long length=[length_s integerValue];
            NSString *offset_s=headers[@"Upload-Offset"];
            if(offset_s){
                long offset=[length_s integerValue];
                
                if(offset>length){
                    //the server gives something wrong
                }else if(offset==length){
                    [_upload onUploadDone];
                    return;
                }else{
                    _upload.offset=offset;
                    [_upload uploadFile];
                    return;
                }
            }else{
                //error: the server does not give offset
            }
        }else{
            //TODO: what to do?
        }
    }
}
@end
@interface HTTPitemCreateFile : HTTPitem
@property (nonatomic,weak) TUSResumableUpload *upload;
//@property (readwrite,copy) void (^onError)(NSError* error);
@property (readwrite,copy) void (^onLocationDetermined)(NSString *location);
@property (nonatomic,strong) NSURLConnection *connection;
@end

@implementation HTTPitemCreateFile
-(HTTPitemCreateFile *)init:(TUSResumableUpload *)upload{
    self=[super init];
    if(self){
        self.upload=upload;
    }
    return self;
}
//-(void)dealloc{
//
//}
-(void)sendRequest:(NSUInteger) size ourl:(NSURL *)ourl{
    NSString *meta=[NSString stringWithFormat:@"sha256 %@",[_upload sha256_base64]];
    NSDictionary *headers = @{ //HTTP_CONTENT_RANGE: [self contentRangeWithSize:size],
        @"Tus-Resumable": @"1.0.0",
        @"Upload-Length": [NSString stringWithFormat:@"%lu",(unsigned long)size]
        ,
        @"Upload-Metadata": meta //@"filename d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg==,is_confidential" //is this useful? needed?
        //TODO: sha256, last modification date
        //  should also be sent when do checkFile
        //  and sha256 should become the ID and base64(fingerprint).
    } ;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:ourl cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:HTTP_POST];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    //    POST /files HTTP/1.1
    //    Host: tus.example.org
    //    Content-Length: 0
    //    Upload-Length: 100
    //    Tus-Resumable: 1.0.0
    //    Upload-Metadata: filename d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg==,is_confidential
    
    
    //   curl -v -X POST -H "Upload-Length: 100" -H "Tus-Resumable: 1.0.0" -H "Upload-Metadata: filename d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg==,is_confidential" http://192.168.254.138:8080/Receiver/files
    
    
    
    self.connection  = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    
}
- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSDictionary *headers = [httpResponse allHeaderFields];
    NSLog(@"response:%@",httpResponse);
    /*
     Connection =     (
     "keep-alive"
     );
     "Content-Length" =     (     //why this header? it tells http body is empty!
     0
     );
     Date =     (
     "Thu, 18 Jun 2020 11:46:45 GMT"
     );
     "Keep-Alive" =     (
     "timeout=20"
     );
     Location =     (
     "http://192.168.254.138:8080/Receiver/files/08b26888_757b_45db_a829_b3a836122645"
     );
     "Tus-Resumable" =     (
     "1.0.0"
     );
     "X-Content-Type-Options" =     (
     nosniff
     );
     
     */
    NSString *location = [headers valueForKey:HTTP_LOCATION];
    if(location){
        self.onLocationDetermined(location);
    }else{ //no Location
        //                NSString *version=[headers valueForKey:@"Tus-Resumable"];
        NSError *error=[[NSError alloc]initWithDomain:@"Location is not found" code:-1 userInfo:headers];
        self.onError(error);
    }
}
@end

@interface HTTPitemUploadFile : HTTPitem
@property (nonatomic,weak) TUSResumableUpload *upload;
@property (readwrite,copy) void (^onOffset)(NSInteger offset,int statusCode);
@property (strong, nonatomic) NSInputStream* inputStream;
@property (strong, nonatomic) NSOutputStream* outputStream;
@property (nonatomic,strong) NSURLConnection *connection;
/* if we sent 1 byte, then this increase 1.
 this is not the offset of this chunk of data in the big file.
 */
//@property (nonatomic) long long offsetToSend;

@end

@implementation HTTPitemUploadFile{
    long long offsetToSend;
    BOOL stopped;
}


-(HTTPitemUploadFile *)init:(TUSResumableUpload *)upload{
    self=[super init];
    if(self){
        offsetToSend=0;
        stopped=NO;
        self.upload=upload;
        //        [self createBoundInputStream:&inStream
        //                        outputStream:&outStream
        //                          bufferSize:TUS_BUFSIZE];
        CFReadStreamRef     readStream=NULL;
        CFWriteStreamRef    writeStream=NULL;
        //            assert( (inputStreamPtr != NULL) || (outputStreamPtr != NULL) );
#if defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && (__MAC_OS_X_VERSION_MIN_REQUIRED < 1070)
#error If you support Mac OS X prior to 10.7, you must re-enable CFStreamCreateBoundPairCompat.
#endif
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && (__IPHONE_OS_VERSION_MIN_REQUIRED < 50000)
#error If you support iOS prior to 5.0, you must re-enable CFStreamCreateBoundPairCompat.
#endif
        
        //    if (NO) {
        //        CFStreamCreateBoundPairCompat(
        //                                      NULL,
        //                                      ((inputStreamPtr  != nil) ? &readStream : NULL),
        //                                      ((outputStreamPtr != nil) ? &writeStream : NULL),
        //                                      (CFIndex) bufferSize
        //                                      );
        //    } else {
        if(NO){
            CFStreamCreateBoundPair(NULL,&readStream,&writeStream,(CFIndex) TUS_BUFSIZE);
            self.inputStream = CFBridgingRelease(readStream);
            self.outputStream = CFBridgingRelease(writeStream);
        }else{
            NSInputStream *inputStream;
            NSOutputStream *outputStream;
            [NSStream getBoundStreamsWithBufferSize:TUS_BUFSIZE inputStream:&inputStream outputStream:&outputStream];
            self.inputStream = inputStream;
            self.outputStream =outputStream;
        }
        //    }
        self.outputStream.delegate = self;
    }
    return self;
}

-(void)sendRequest{ //:(long long)offset size:(long long)size
    offsetToSend=_upload.offset;
    stopped=NO;
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream open];
    long long //offsetToSend=_upload.offset,
    size= _upload.sizeFile;
    //    NSString *contentRange = [self contentRangeFrom:offset to:size-1 size:size];
    NSDictionary *headers = //@{ HTTP_CONTENT_RANGE: contentRange };
    @{@"Content-Type":@"application/offset+octet-stream",
      @"Upload-Offset":[NSString stringWithFormat:@"%lld",offsetToSend],
      @"Content-Length":[NSString stringWithFormat:@"%lld",size],
      @"Tus-Resumable": @"1.0.0"
    };
    /*
     Content-Type: application/offset+octet-stream
     Content-Length: 30
     Upload-Offset: 70
     Tus-Resumable: 1.0.0
     */
    
    NSLog(@"Resuming upload file %@(%@) from offset %lld-%lld to %@", _upload.sha256_hex,_upload.pathFile, offsetToSend, size,_upload.url);
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:_upload.url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:@"PATCH"]; //HTTP_PUT
    request.HTTPBodyStream=self.inputStream; //[self dataStream]
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    
}

//-(void)dealloc{
//
//}

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSDictionary *headers = [httpResponse allHeaderFields];
    NSLog(@"response:%@",httpResponse);
    /*
     <NSHTTPURLResponse: 0x2808bff20> { URL: http://192.168.254.138:8080/Receiver/files/996d96b5_27e2_4f03_a3da_acf9a61d8301 } { Status Code: 204, Headers {
     Connection =     (
     "keep-alive"
     );
     Date =     (
     "Tue, 16 Jun 2020 02:37:55 GMT"
     );
     "Keep-Alive" =     (
     "timeout=20"
     );
     "Tus-Resumable" =     (
     "1.0.0"
     );
     "Upload-Offset" =     (
     31389
     );
     "X-Content-Type-Options" =     (
     nosniff
     );
     } }
     */
    NSString *offset_s = [headers valueForKey:@"Upload-Offset"];
    if(offset_s){
        NSInteger offset=[offset_s integerValue];
        self.onOffset(offset,httpResponse.statusCode);
    }else{ //no Location
        //                NSString *version=[headers valueForKey:@"Tus-Resumable"];
        NSError *error=[[NSError alloc]initWithDomain:@"PATCH does not give UpLoad-Offset" code:-1 userInfo:headers];
        self.onError(error);
        //        [self connection:connection didFailWithError:error];
    }
    
}


//read bytes from file
- (NSUInteger)getBytes:(uint8_t *)buffer
            fromOffset:(long long)offset
                length:(NSUInteger)length
                 error:(NSError **)error{
    NSError *e=*error;
    NSRange range = NSMakeRange(offset, length);
    if (offset + length > _upload.sizeFile) {
        e=[NSError errorWithDomain:@"end of file" code:-1 userInfo:nil];
        length=0;
    }else{
        if(useNSData){
            [_upload.data getBytes:buffer range:range];
        }else{
            FILE *f=_upload.f;
            if(ftell(f)!=offset){
                if(fseek(f, offset, SEEK_SET)!=0){
                    e=[NSError errorWithDomain:[NSString stringWithFormat:@"failed to seek to %lu",(unsigned long)length] code:-1 userInfo:nil];
                }
            }
            long len=fread(buffer,1,length,f);
            if(len!=length){
                e=[NSError errorWithDomain:[NSString stringWithFormat:@"length %lu < %lu",len,length] code:-1 userInfo:nil];
            }
        }
    }
    return length;
}


#pragma mark - NSStreamDelegate Protocol Methods
//How to notify the end of stream?
- (void)stream:(NSStream *)aStream
   handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            NSLog(@"TUSData stream opened");
        } break;
        case NSStreamEventHasSpaceAvailable: {
            if(stopped){
                [self.outputStream close];
                [self stop_do];
                return;
            }
            uint8_t buffer[TUS_BUFSIZE];
            long long length = TUS_BUFSIZE;
            long long dlen= _upload.sizeFile - offsetToSend;
            if (length > dlen) {
                length = dlen;
            }
            if (!length) {
                [[self outputStream] setDelegate:nil];
                [[self outputStream] close];
                [_upload onDataSent];
                return;
            }
            NSLog(@"Reading %lld bytes from %lld to %lld until %lld", length, offsetToSend, offsetToSend + length, _upload.sizeFile);
            NSError* error = NULL;
            NSUInteger bytesRead = [self getBytes:buffer
                                       fromOffset:offsetToSend
                                           length:length
                                            error:&error];
            if (!bytesRead) { //TODO: check its return value.
                NSLog(@"Unable to read bytes due to: %@", error);
                //                if (self.failureBlock) {
                //                    self.failureBlock(error);Ï
                //                }
                [_upload onStreamError:error];
            } else {
                NSInteger bytesWritten = [[self outputStream] write:buffer
                                                          maxLength:bytesRead];
                if (bytesWritten <= 0) {
                    NSLog(@"Network write error %@", [aStream streamError]);
                } else {
                    if (bytesRead != (NSUInteger)bytesWritten) {
                        NSLog(@"Read %lu bytes from buffer but only wrote %lu to the network",
                              bytesRead, bytesWritten);
                    }
                    offsetToSend+=bytesWritten; //[self setOffset:[self offset] + bytesWritten];
                }
            }
        } break;
        case NSStreamEventErrorOccurred: {
            [_upload onStreamError:[aStream streamError]];
        } break;
        case NSStreamEventHasBytesAvailable:
        case NSStreamEventEndEncountered:
        default:
            assert(NO);     // should never happen for the output stream
            break;
    }
}

//// A category on NSStream that provides a nice, Objective-C friendly way to create
//// bound pairs of streams.  Adapted from the SimpleURLConnections sample code.
//- (void)createBoundInputStream:(NSInputStream **)inputStreamPtr
//                  outputStream:(NSOutputStream **)outputStreamPtr
//                    bufferSize:(NSUInteger)bufferSize
//{
//    CFReadStreamRef     readStream;
//    CFWriteStreamRef    writeStream;
//
//    assert( (inputStreamPtr != NULL) || (outputStreamPtr != NULL) );
//
//    readStream = NULL;
//    writeStream = NULL;
//
//#if defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && (__MAC_OS_X_VERSION_MIN_REQUIRED < 1070)
//#error If you support Mac OS X prior to 10.7, you must re-enable CFStreamCreateBoundPairCompat.
//#endif
//#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && (__IPHONE_OS_VERSION_MIN_REQUIRED < 50000)
//#error If you support iOS prior to 5.0, you must re-enable CFStreamCreateBoundPairCompat.
//#endif
//
//    //    if (NO) {
//    //        CFStreamCreateBoundPairCompat(
//    //                                      NULL,
//    //                                      ((inputStreamPtr  != nil) ? &readStream : NULL),
//    //                                      ((outputStreamPtr != nil) ? &writeStream : NULL),
//    //                                      (CFIndex) bufferSize
//    //                                      );
//    //    } else {
//    CFStreamCreateBoundPair(
//                            NULL,
//                            ((inputStreamPtr  != nil) ? &readStream : NULL),
//                            ((outputStreamPtr != nil) ? &writeStream : NULL),
//                            (CFIndex) bufferSize
//                            );
//    //    }
//
//    if (inputStreamPtr != NULL) {
//        *inputStreamPtr  = CFBridgingRelease(readStream);
//    }
//    if (outputStreamPtr != NULL) {
//        *outputStreamPtr = CFBridgingRelease(writeStream);
//    }
//}

- (void)stop{
    stopped=YES;
    [[self outputStream] close];
}
- (void)stop_do{
    [[self outputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [[self outputStream] setDelegate:nil];
    [self setOutputStream:nil];
    
    [self.inputStream setDelegate:nil];
    [self.inputStream close];
    self.inputStream=nil;
}


@end

@implementation TUSResumableUpload{
}

- (id)initWithURL:(NSString *)urlBase //with ending "/"
             path:(NSString *)pathFile
      fingerprint:(NSString *)fingerprint{ //TODO: remove fingerprint use sha256
    self = [super init];
    if (self) {
        _extraCheck=NO;
        self.pathFile=pathFile;
        NSString *url=[NSString stringWithFormat:@"%@files/",urlBase];
        self.endpoint=[NSURL URLWithString:url];  //with ending "/"? Yes!
        self.sha256_hex=fingerprint; //        [self setFingerprint:fingerprint];
    }
    return self;
}

+(TUSResumableUpload *)task:(NSString *)urlBase
                       path:(NSString *)pathFile
//                fingerprint:(NSString *)fingerprint
{ //TODO: remove fingerprint
    [TUSResumableUpload resumableUploads];
    NSData *osha256;
    NSData *dataFile=nil;
    FILE *f=NULL;
    if(useNSData){ //YES||
        NSData *dataFile=[NSData dataWithContentsOfFile:pathFile];
        //        self.data=dataFile; //TUSData *data=[[TUSData alloc]initWithData:dataFile upload:self];  //TODO: if I do not do parallel, then TUSData can be merged into this class.
        //        self.sizeFile=dataFile.length;
        osha256=[TUSResumableUpload doSha256withData:dataFile];
    }else{
        f=fopen(pathFile.fileSystemRepresentation,"r");
        if(f){
            osha256=[TUSResumableUpload doSha256:f];
        }else{
            NSLog(@"can not read from map file, not exists:%@",pathFile);
            //TODO: try its backup.
            //                NSError *error=nil;
            //                [self onStreamError:error];
            return nil;
        }
        //        self.f=f;
    }
    if(YES){
        unsigned long n=osha256.length;
        NSLog(@"sha256:%d",n);
        const uint8_t *p=(const uint8_t *)osha256.bytes;
        for(int i=0;i<32;i++){
            NSLog(@"%02X",p[i]);
        }
    }
    NSString *fingerprint=[osha256 toHex];
    
    NSString *key=[NSString stringWithFormat:@"%@:%@",urlBase,fingerprint];
    TUSResumableUpload *upload=ouploads[key];
    if(upload){}else{
        upload=[[TUSResumableUpload alloc]initWithURL:urlBase path:pathFile fingerprint:fingerprint];
        if(useNSData){
            upload.data=dataFile;
            upload.sizeFile=dataFile.length;
        }else{
            upload.f=f;
            int fd = fileno(f); //if you have a stream (e.g. from fopen), not a file descriptor.
            struct stat buf;
            fstat(fd, &buf);
            upload.sizeFile=buf.st_size;
        }
        ouploads[key]=upload;
        //        [upload release];
    }
    return upload;
}

/*
 after we get some info from server, we might use a new TUSData.
 */
//-(void)set:(int) fake
//      data:(TUSData *)data
//{
//    [self setData:data];
//}

- (void) start{
    if (self.progressBlock) {
        //TODO: this is wrong!!
        self.progressBlock(0, 0);
    }
    [TUSResumableUpload resumableUploads];
    if(self.url){}else{ //self.data
        //        NSData *osha256;
        //        if(useNSData){ //YES||
        //            NSData *dataFile=[NSData dataWithContentsOfFile:self.pathFile];
        //            self.data=dataFile; //TUSData *data=[[TUSData alloc]initWithData:dataFile upload:self];  //TODO: if I do not do parallel, then TUSData can be merged into this class.
        //            self.sizeFile=dataFile.length;
        //            osha256=[TUSResumableUpload doSha256withData:dataFile];
        //        }else{
        //            FILE *f=fopen(self.pathFile.fileSystemRepresentation,"r");
        //            if(f){
        //                osha256=[TUSResumableUpload doSha256:f];
        //            }else{
        //                NSLog(@"can not read from map file, not exists:%@",self.pathFile);
        //                //TODO: try its backup.
        //                NSError *error=nil;
        //                [self onStreamError:error];
        //                return;
        //            }
        //            self.f=f;
        //            int fd = fileno(f); //if you have a stream (e.g. from fopen), not a file descriptor.
        //            struct stat buf;
        //            fstat(fd, &buf);
        //            self.sizeFile=buf.st_size;
        //        }
        //        self.sha256_hex=[osha256 toHex];
        self.url=[NSURL URLWithString:[NSString stringWithFormat:@"%@%@",self.endpoint,self.sha256_hex]];
        NSLog(@"url:%@",self.url);
    }
    //we can just make it up.
    //    "http://192.168.254.138:8080/Receiver/files/08b26888_757b_45db_a829_b3a836122645"
    //    NSString *base64_sha256=nil; //TODO: ....
    //    NSString *uploadUrl =[NSString stringWithFormat:@"%@%@",self.endpoint,base64_sha256];// [uploads valueForKey:self.fingerprint];
    //    if (uploadUrl == nil) {
    //        NSLog(@"No resumable upload URL for fingerprint %@", self.fingerprint);
    //        [self createFile];
    //        return;
    //    }
    //
    //    [self setUrl:[NSURL URLWithString:uploadUrl]];
    [self checkFile];
}
-(NSString *)sha256_base64{
    return [[self.sha256_hex dataUsingEncoding: NSASCIIStringEncoding] base64EncodedStringWithOptions:0];
}

- (void) createFile{
    [self setState:CreatingFile];
    HTTPitemCreateFile *item=[[HTTPitemCreateFile alloc]init:self];
    __weak HTTPitemCreateFile *itemw=item;
    item.onError=^(NSError *error){
        // [self connection:connection didFailWithError:error];
    };
    item.onError=^(NSError *error){
        NSLog(@"ERROR: connection did fail due to: %@", error);
        [itemw.connection cancel];
        if (self.failureBlock) {
            self.failureBlock(error);
        }
        
    };
    
    item.onLocationDetermined=^(NSString *location){
        if([location isEqualToString:self.url.absoluteString]){
            
        }else{
            /*
             location is not right:
             http://192.168.254.138:8080/Receiver/files/A38D4B6A8D60EA05BD9BD3CCFD38B4C9E627B5DC134EE0E516B3464FAE516431
             http://192.168.254.138:8080/Receiver/files/A38D4B6A8D60EA05BD9BD3CCFD38B4C9E627B5DC134EE0E516B3464FAE516431
             */
            NSLog(@"location is not right %d %d  :%@ %@",location.length, self.url.absoluteString.length,location, self.url);
        }
        [self setUrl:[NSURL URLWithString:location]];
        NSLog(@"Created resumable upload at %@ for fingerprint %@",[self url], self.sha256_hex);
        [TUSResumableUpload resumableUploads];
        //        [uploads setValue:location forKey:[self fingerprint]];
        [TUSResumableUpload saveUpLoading];
        [self uploadFile];
    };
    [item sendRequest:self.sizeFile ourl:self.endpoint];
}
-(void)onFailed:(NSString *)msg{
    if (self.failureBlock) {
        NSError *error=[NSError errorWithDomain:msg code:-1 userInfo:nil];
        self.failureBlock(error);
    }
}

- (void) checkFile
{
    [self setState:CheckingFile];
    
    
    HTTPitemCheckFile *item=[[HTTPitemCheckFile alloc]init:self];
    __weak HTTPitemCheckFile *itemw=item;
    item.onCodeUnexpected=^(long statusCode){
        NSLog(@"Server responded with %ld. Restarting upload", statusCode);
        if(self.extraCheck){
            NSString *msg=@"failed on extra check";
            NSLog(@"%@",msg);
            [self onFailed:msg];
        }else{
            [self createFile];
        }
    };
    item.onOffset=^(long long offset){
        self.offset=offset;
        [self uploadFile];
    };
    item.onError=^(NSError *error){
        NSLog(@"ERROR: connection did fail due to: %@", error);
        [itemw.connection cancel];
        if (self.failureBlock) {
            self.failureBlock(error);
        }
    };
    [item sendRequest];
}

- (void) uploadFile{
    //__weak TUSResumableUpload *upload=self;
    [self setState:UploadingFile];
    HTTPitemUploadFile *item=[[HTTPitemUploadFile alloc]init:self];
    __weak HTTPitemUploadFile *itemw=item;
    item.onError=^(NSError *error){
        NSLog(@"ERROR: connection did fail due to: %@", error);
        [itemw stop];
        [itemw.connection cancel];
        if (self.failureBlock) {
            self.failureBlock(error);
        }
    };
    item.onOffset=^(NSInteger offset,int statusCode){
        long long sizeFile=self.sizeFile;
        if(offset !=sizeFile){
            NSLog(@"we have sent the data, but offset:%ld is not right %lld yet",(long)offset, sizeFile);
            //what to do?
            //whetever is missing we send more
        }
        self.offset=offset;
        if(offset < self.sizeFile){
            if(statusCode==100){ //100: this request has been accepted, 400: this request has been rejected
                [self uploadFile];
            }else if(statusCode==400){ //100: this request has been accepted, 400: this request has been rejected
                [itemw stop];
                [self uploadFile];
            }else{
                //TODO: we are expecting 100
            }
        }else{
            if(statusCode==409){ //sha256 is not right
                //TODO: sha256 check failed.
            }else if(statusCode==200){
                //            [self onUploadDone]; //TODO: put it off
                self.extraCheck=YES;
                [self checkFile];
            }else{
                //TODO: we are expecting 200 or 409
            }
        }
    };
    [item sendRequest];
}



-(void)onStreamError://(TUSData *)data error:
(NSError *)error{
    NSLog(@"TUSData stream error %@", error);
    //if (self.failureBlock) {
    //    self.failureBlock([aStream streamError]);
    //}
    NSLog(@"Failed to upload to %@ for fingerprint %@:%@", self.url, self.sha256_hex, error);
    if (self.failureBlock) {
        self.failureBlock(error);
    }
}

-(void)onDataSent//:(TUSData *)data
{
    [self setState:Idle];
    if(NO){ //too early to call this
        //        [self onUploadDone]; //TODO: put it off
    }else{
        //TODO: to check with server.
        __weak TUSResumableUpload *upload=self;
        dispatch_async(dispatch_get_main_queue(), ^{
            //            [upload start];
        });
        
    }
}

-(void)onUploadDone{ //when should this be called. from TUSData, seems too early.
    [self setState:Idle];
    NSLog(@"Finished upload to %@ for fingerprint %@", self. url,self.sha256_hex);
    //    [TUSResumableUpload resumableUploads];
    //[uploads removeObjectForKey:self.fingerprint];
    [TUSResumableUpload saveUpLoading];
    if (self.resultBlock) {
        self.resultBlock(self.url);
    }
}
//-(void)onLocationDetermined:(                NSString *)location{
//    [self setUrl:[NSURL URLWithString:location]];
//    NSLog(@"Created resumable upload at %@ for fingerprint %@",
//          [self url], [self fingerprint]);
//    [TUSResumableUpload resumableUploads];
//    [uploads setValue:location forKey:[self fingerprint]];
//    [TUSResumableUpload saveUpLoading];
//    [self uploadFile];
//}

- (void)connection:(NSURLConnection *)connection
   didSendBodyData:(NSInteger)bytesWritten
 totalBytesWritten:(NSInteger)totalBytesWritten
totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    NSLog(@"bytes sent:%ld / %ld / %ld ", bytesWritten,totalBytesWritten, totalBytesExpectedToWrite);
    switch([self state]) {
        case UploadingFile:
            if (self.progressBlock) {
                self.progressBlock(totalBytesWritten+self.offset, self.sizeFile+self.offset);
            }
            break;
        default:
            break;
    }
    
}


#pragma mark - Private Methods
- (TUSRange)rangeFromHeader:(NSString*)rangeHeader
{
    long long first = TUSInvalidRange;
    long long last = TUSInvalidRange;
    
    NSString* bytesPrefix = [HTTP_BYTES_UNIT stringByAppendingString:HTTP_RANGE_EQUAL];
    NSScanner* rangeScanner = [NSScanner scannerWithString:rangeHeader];
    BOOL success = [rangeScanner scanUpToString:bytesPrefix intoString:NULL];
    if (!success) {
        NSLog(@"Failed to scan up to '%@' from '%@'", bytesPrefix, rangeHeader);
    }
    
    success = [rangeScanner scanString:bytesPrefix intoString:NULL];
    if (!success) {
        NSLog(@"Failed to scan '%@' from '%@'", bytesPrefix, rangeHeader);
    }
    
    success = [rangeScanner scanLongLong:&first];
    if (!success) {
        NSLog(@"Failed to first byte from '%@'", rangeHeader);
    }
    
    success = [rangeScanner scanString:HTTP_RANGE_DASH intoString:NULL];
    if (!success) {
        NSLog(@"Failed to byte-range separator from '%@'", rangeHeader);
    }
    
    success = [rangeScanner scanLongLong:&last];
    if (!success) {
        NSLog(@"Failed to last byte from '%@'", rangeHeader);
    }
    
    if (first > last) {
        first = TUSInvalidRange;
        last = TUSInvalidRange;
    }
    if (first < 0) {
        first = TUSInvalidRange;
    }
    if (last < 0) {
        last = TUSInvalidRange;
    }
    
    return TUSMakeRange(first, last);
}

- (NSString*)contentRangeFrom:(long long)first to:(long long)last size:(long long)size
{
    return [NSString stringWithFormat:@"%@ %lld-%lld/%lld", HTTP_BYTES_UNIT, first, last, size];
}

- (NSString*)contentRangeWithSize:(long long)size
{
    return [NSString stringWithFormat:@"%@ */%lld", HTTP_BYTES_UNIT, size];
}


+(void)saveUpLoading{
    //TODO: save many meta info.
    NSURL* fileURL = [TUSResumableUpload resumableUploadsFilePath];
    
    // all data sent?
    //  final verified?  server calculate sha256
    NSMutableDictionary<NSString *,NSObject *> *dict=[[NSMutableDictionary alloc]init];
    BOOL success = [dict writeToURL:fileURL atomically:YES];
    if (!success) {
        NSLog(@"Unable to save resumableUploads file");
    }
}

+ (void)resumableUploads{
    if(ouploads){}else{
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSURL *resumableUploadsPath=[TUSResumableUpload resumableUploadsFilePath];
            NSMutableDictionary<NSString *,NSObject *> *dict = [NSMutableDictionary dictionaryWithContentsOfURL:resumableUploadsPath];
            ouploads= [[NSMutableDictionary alloc] init];
            if (dict) {
                for(NSString *key in dict) { //key is the url
                    NSString *location=dict[key];
                    NSString *urlBase=[location stringByDeletingLastPathComponent];
                    //NSString *key=[NSString stringWithFormat:@"%@:%@",urlBase,key];
                    NSString *pathFile=nil; //TODO:
                    TUSResumableUpload *upload=[[TUSResumableUpload alloc]initWithURL:urlBase path:pathFile fingerprint:key];
                    upload.url=[NSURL URLWithString:location];
                    ouploads[key]=upload;
                    //TODO: if upload is not donw, then trigger it to continue.
                }
            }else{
                //                uploads = [[NSMutableDictionary alloc] init];
            }
        });
    }
    //    return uploads;
}

+(NSURL*)resumableUploadsFilePath{
    if(fileUploading){}else{
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSArray* directories = [fileManager URLsForDirectory:NSApplicationSupportDirectory
                                                   inDomains:NSUserDomainMask];
        NSURL* applicationSupportDirectoryURL = [directories lastObject];
        NSString* applicationSupportDirectoryPath = [applicationSupportDirectoryURL absoluteString];
        BOOL isDirectory = NO;
        if (![fileManager fileExistsAtPath:applicationSupportDirectoryPath
                               isDirectory:&isDirectory]) {
            NSError* error = nil;
            BOOL success = [fileManager createDirectoryAtURL:applicationSupportDirectoryURL
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:&error];
            if (!success) {
                NSLog(@"Unable to create %@ directory due to: %@",
                      applicationSupportDirectoryURL,
                      error);
            }
        }
        fileUploading=[applicationSupportDirectoryURL URLByAppendingPathComponent:@"TUSResumableUploads.plist"];
        //        [fileUploading retain];
        NSLog(@"local saved:%@",fileUploading);
        //  file:///var/mobile/Containers/Data/Application/4C47C718-66B9-4C80-8434-6C5AB711D2D2/Library/Application%20Support/TUSResumableUploads.plist
    }
    return fileUploading;
}


//- (NSInputStream*)dataStream
//{
//    return _inputStream;
//}


//- (long long)sizeFile
//{
//    return _data.length;
//}

+ (NSData *)doSha256withData:(NSData *)dataIn {
    NSMutableData *macOut = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    if(NO){
        CC_SHA256(dataIn.bytes, dataIn.length, macOut.mutableBytes);
    }else{
        CC_SHA256_CTX ctx;
        int ret= CC_SHA256_Init(&ctx);
        //        NSLog(@"ret:%d",ret);
        ret= CC_SHA256_Update(&ctx, dataIn.bytes, (unsigned int)dataIn.length);
        //        NSLog(@"ret:%d",ret);
        //        unsigned char md[33];
        ret= CC_SHA256_Final(macOut.mutableBytes, &ctx);
        //        md[32]=0;
        //        NSLog(@"ret:%d %@",ret,[macOut base64EncodedStringWithOptions:0]);
        //        md[32]=0;
    }
    return macOut;
}
+ (NSData *)doSha256:(FILE *)f {
    NSMutableData *macOut = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    uint8_t data[4096];
    fseek(f, 0,SEEK_SET);
    CC_SHA256_CTX ctx;
    int ret= CC_SHA256_Init(&ctx);
    if(YES){
        ret= CC_SHA256_Final(macOut.mutableBytes, &ctx);
        NSLog(@"sha256 of empty string:%@",[macOut toHex]);
        CC_SHA256_Init(&ctx);
    }
    //    NSLog(@"ret:%d",ret);
    while(true){
        unsigned long length=fread(data, 1,sizeof(data) , f);
        ret= CC_SHA256_Update(&ctx, data, length);
        //        NSLog(@"ret:%d",ret);
        if(feof(f)) break;
    }
    fseek(f, 0, SEEK_SET);
    //        unsigned char md[33];
    ret= CC_SHA256_Final(macOut.mutableBytes, &ctx);
    //        md[32]=0;
//    NSLog(@"ret:%d %@",ret,[macOut base64EncodedStringWithOptions:0]);
    //        md[32]=0;
    return macOut;
}


@end
