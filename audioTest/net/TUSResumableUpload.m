//
//  TUSResumableUpload.m
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//

//#import "TUSKit.h"
//#import "TUSData.h"

#import "TUSResumableUpload.h"

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
static NSMutableDictionary<NSString *,NSString *> *uploads=nil; //just map from fingerprint to location
static NSMutableDictionary<NSString *,TUSResumableUpload *> *ouploads=nil; //just map from urlBase+fingerprint to Object

@interface TUSResumableUpload ()<NSURLConnectionDelegate,NSStreamDelegate>
@property (strong, nonatomic) NSInputStream* inputStream;
@property (strong, nonatomic) NSOutputStream* outputStream;
@property (strong, nonatomic) NSData* data; //data contains the whole file.
//@property (strong, nonatomic) TUSData *data;
@property (strong, nonatomic) NSURL *endpoint; //the base url
//http://192.168.254.138:8080/Receiver/
@property (strong, nonatomic) NSURL *url; //the url to upload this file
//http://192.168.254.138:8080/Receiver/files/61d12f13_9e91_4185_ae9f_950b181c8383
@property (strong, nonatomic) NSString *pathFile;
@property (strong, nonatomic) NSString *fingerprint;
@property (nonatomic) long long offset; //when is it set?
@property (nonatomic) TUSUploadState state;
@property (strong, nonatomic) void (^progress)(NSInteger bytesWritten, NSInteger bytesTotal);
@end

@implementation TUSResumableUpload

- (id)initWithURL:(NSString *)urlBase //with ending "/"
             path:(NSString *)pathFile
      fingerprint:(NSString *)fingerprint{
    self = [super init];
    if (self) {
        self.pathFile=pathFile;
        NSString *url=[NSString stringWithFormat:@"%@files/",urlBase];
        [self setEndpoint:[NSURL URLWithString:url]];
        [self setFingerprint:fingerprint];
    }
    return self;
}

+(TUSResumableUpload *)task:(NSString *)urlBase
                path:(NSString *)pathFile
                fingerprint:(NSString *)fingerprint{
    [TUSResumableUpload resumableUploads];
    NSString *key=[NSString stringWithFormat:@"%@:%@",urlBase,fingerprint];
    TUSResumableUpload *upload=ouploads[key];
    if(upload){}else{
        upload=[[TUSResumableUpload alloc]initWithURL:urlBase path:pathFile fingerprint:fingerprint];
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
    if(self.data){}else{
    NSData *dataFile=[NSData dataWithContentsOfFile:self.pathFile];
    self.data=dataFile; //TUSData *data=[[TUSData alloc]initWithData:dataFile upload:self];  //TODO: if I do not do parallel, then TUSData can be merged into this class.
    }
    NSString *uploadUrl = [uploads valueForKey:self.fingerprint];
    if (uploadUrl == nil) {
        NSLog(@"No resumable upload URL for fingerprint %@", self.fingerprint);
        [self createFile];
        return;
    }
    
    [self setUrl:[NSURL URLWithString:uploadUrl]];
    [self checkFile];
}

- (void) createFile
{
    [self setState:CreatingFile];
    
    NSUInteger size = self.sizeFile;
    NSDictionary *headers = @{ HTTP_CONTENT_RANGE: [self contentRangeWithSize:size],@"Tus-Resumable": @"1.0.0",
                               @"Upload-Length": [NSString stringWithFormat:@"%lu",size],
                               @"Upload-Metadata": @"filename d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg==,is_confidential" //is this useful? needed?
    } ;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self endpoint] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:REQUEST_TIMEOUT];
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
    
    
    
    NSURLConnection *connection __unused = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void) checkFile
{
    [self setState:CheckingFile];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:HTTP_HEAD];
    [request setHTTPShouldHandleCookies:NO];
    
    NSURLConnection *connection __unused = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void) uploadFile{
    [self setState:UploadingFile];
    
    NSInputStream* inStream = nil;
    NSOutputStream* outStream = nil;
    [self createBoundInputStream:&inStream
                        outputStream:&outStream
                          bufferSize:TUS_BUFSIZE];
    assert(inStream != nil);
    assert(outStream != nil);
    self.inputStream = inStream;
    self.outputStream = outStream;
    self.outputStream.delegate = self;
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                 forMode:NSDefaultRunLoopMode];
    [self.outputStream open];
    
    self.offsetToSend=self.offset;
//    self.data=data;
    long long size = self.sizeFile;
    long long offset = self.offset;
    //    NSString *contentRange = [self contentRangeFrom:offset to:size-1 size:size];
    NSDictionary *headers = //@{ HTTP_CONTENT_RANGE: contentRange };
    @{@"Content-Type":@"application/offset+octet-stream",
      @"Content-Length":[NSString stringWithFormat:@"%lld",size],
      @"Upload-Offset":[NSString stringWithFormat:@"%lld",offset],
      @"Tus-Resumable": @"1.0.0"
    };
    /*
     Content-Type: application/offset+octet-stream
     Content-Length: 30
     Upload-Offset: 70
     Tus-Resumable: 1.0.0
     */
    
    NSLog(@"Resuming upload file %@(%@) from offset %lld-%lld to %@", self.fingerprint,self.pathFile, offset, size,self.url);
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:@"PATCH"]; //HTTP_PUT
    request.HTTPBodyStream=self.inputStream; //[self dataStream]
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLConnection *connection __unused = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

#pragma mark - NSURLConnectionDelegate Protocol Delegate Methods
- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error {
    NSLog(@"ERROR: connection did fail due to: %@", error);
    [connection cancel];
    [self stop];
    if (self.failureBlock) {
        self.failureBlock(error);
    }
}

#pragma mark - NSURLConnectionDataDelegate Protocol Delegate Methods

// TODO: Add support to re-initialize dataStream
- (NSInputStream *)connection:(NSURLConnection *)connection
            needNewBodyStream:(NSURLRequest *)request
{
    NSLog(@"ERROR: connection requested new body stream, which is currently not supported");
    return nil;
}

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSDictionary *headers = [httpResponse allHeaderFields];
    NSLog(@"response:%@",httpResponse);
    switch([self state]) {
            /* at first do checking, then if needed, we create it. TODO: check Tus-Resumable header.
             Before this, I should send OPTIONS to gather some info about the server.
             */
        case CheckingFile: {
            if (httpResponse.statusCode != 200) {
                NSLog(@"Server responded with %ld. Restarting upload",
                      httpResponse.statusCode);
                [self createFile];
                return;
            }
            NSString *rangeHeader = [headers valueForKey:HTTP_RANGE];
            if (rangeHeader) {
                TUSRange range = [self rangeFromHeader:rangeHeader];
                [self setOffset:range.last];
                NSLog(@"Resumable upload at %@ for %@ from %lld (%@)",
                      [self url], [self fingerprint], self.offset, rangeHeader);
            }
            else {
                NSLog(@"Restarting upload at %@ for %@", [self url], [self fingerprint]);
            }
            [self uploadFile];
            break;
        }
        case CreatingFile: {
            NSString *location = [headers valueForKey:HTTP_LOCATION];
            if(location){
                [self onLocationDetermined:location];
            }else{ //no Location
                //                NSString *version=[headers valueForKey:@"Tus-Resumable"];
                NSError *error=[[NSError alloc]initWithDomain:@"Location is not found" code:-1 userInfo:headers];
                [self connection:connection didFailWithError:error];
            }
            break;
        }
        case UploadingFile:{
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
                NSInteger offsetStart=self.offset;
                
                if(offset !=offsetStart){
                    NSLog(@"we have sent the data, but offset:%ld is not right %lld yet",offset, offsetStart);
                    //what to do?
                    //whetever is missing we send more
                }
                self.offset=offset;
                if(offset < self.sizeFile){
                    [self uploadFile];
                }
            }else{ //no Location
                //                NSString *version=[headers valueForKey:@"Tus-Resumable"];
                NSError *error=[[NSError alloc]initWithDomain:@"Location is not found" code:-1 userInfo:headers];
                [self connection:connection didFailWithError:error];
            }
            
            break;
        }
        case Idle:
            
            break;
        default:
            break;
    }
}


-(void)onStreamError://(TUSData *)data error:
                     (NSError *)error{
    NSLog(@"TUSData stream error %@", error);
    //if (self.failureBlock) {
    //    self.failureBlock([aStream streamError]);
    //}
    NSLog(@"Failed to upload to %@ for fingerprint %@:%@", self.url, self.fingerprint, error);
    if (self.failureBlock) {
        self.failureBlock(error);
    }
}

-(void)onDataSent//:(TUSData *)data
{
    [self setState:Idle];
    if(NO){ //too early to call this
        [self onUploadedDone];
    }else{
        //TODO: to check with server.
        __weak TUSResumableUpload *upload=self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [upload start];
        });
        
    }
}

-(void)onUploadedDone{ //when should this be called. from TUSData, seems too early.
    [self setState:Idle];
    NSLog(@"Finished upload to %@ for fingerprint %@", self. url,self.fingerprint);
    //    [TUSResumableUpload resumableUploads];
    [uploads removeObjectForKey:self.fingerprint];
    [TUSResumableUpload saveUpLoading];
    if (self.resultBlock) {
        self.resultBlock(self.url);
    }
}
-(void)onLocationDetermined:(                NSString *)location{
    [self setUrl:[NSURL URLWithString:location]];
    NSLog(@"Created resumable upload at %@ for fingerprint %@",
          [self url], [self fingerprint]);
    [TUSResumableUpload resumableUploads];
    [uploads setValue:location forKey:[self fingerprint]];
    [TUSResumableUpload saveUpLoading];
    [self uploadFile];
}

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
    NSURL* fileURL = [TUSResumableUpload resumableUploadsFilePath];
    BOOL success = [uploads writeToURL:fileURL atomically:YES];
    if (!success) {
        NSLog(@"Unable to save resumableUploads file");
    }
}

+ (NSMutableDictionary*)resumableUploads{
    if(uploads){}else{
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSURL *resumableUploadsPath=[TUSResumableUpload resumableUploadsFilePath];
            uploads = [NSMutableDictionary dictionaryWithContentsOfURL:resumableUploadsPath];
            ouploads= [[NSMutableDictionary alloc] init];
            if (uploads) {
                for(NSString *fingerprint in uploads) {
                    NSString *location=uploads[fingerprint];
                    NSString *urlBase=[location stringByDeletingLastPathComponent];
                    NSString *key=[NSString stringWithFormat:@"%@:%@",urlBase,fingerprint];
                    NSString *pathFile=nil; //TODO:
                    TUSResumableUpload *upload=[[TUSResumableUpload alloc]initWithURL:urlBase path:pathFile fingerprint:fingerprint];
                    upload.url=[NSURL URLWithString:location];
                    ouploads[key]=upload;
                    //TODO: if upload is not donw, then trigger it to continue.
                }
            }else{
                uploads = [[NSMutableDictionary alloc] init];
            }
        });
    }
    return uploads;
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

- (void)stop
{
    [[self outputStream] setDelegate:nil];
    [[self outputStream] removeFromRunLoop:[NSRunLoop currentRunLoop]
                                   forMode:NSDefaultRunLoopMode];
    [[self outputStream] close];
    [self setOutputStream:nil];

    [[self inputStream] setDelegate:nil];
    [[self inputStream] close];
    [self setInputStream:nil];
}

- (long long)sizeFile
{
    return _data.length;
}

- (NSUInteger)getBytes:(uint8_t *)buffer
            fromOffset:(long long)offset
                length:(NSUInteger)length
                 error:(NSError **)error
{
    NSRange range = NSMakeRange(offset, length);
    if (offset + length > _data.length) {
        return 0;
    }

    [_data getBytes:buffer range:range];
    return length;
}


#pragma mark - NSStreamDelegate Protocol Methods
- (void)stream:(NSStream *)aStream
   handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            NSLog(@"TUSData stream opened");
        } break;
        case NSStreamEventHasSpaceAvailable: {
            uint8_t buffer[TUS_BUFSIZE];
            long long length = TUS_BUFSIZE;
            if (length > self.sizeFile - [self offsetToSend]) {
                length = self.sizeFile - [self offsetToSend];
            }
            if (!length) {
                [[self outputStream] setDelegate:nil];
                [[self outputStream] close];
                [self onDataSent];
                return;
            }
            NSLog(@"Reading %lld bytes from %lld to %lld until %lld"
                  , length, [self offsetToSend], [self offsetToSend] + length, self.sizeFile);
            NSError* error = NULL;
            NSUInteger bytesRead = [self getBytes:buffer
                                       fromOffset:[self offsetToSend]
                                           length:length
                                            error:&error];
            if (!bytesRead) { //TODO: check its return value.
                NSLog(@"Unable to read bytes due to: %@", error);
//                if (self.failureBlock) {
//                    self.failureBlock(error);Ï
//                }
                [self onStreamError:error];
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
                    self.offsetToSend+=bytesWritten; //[self setOffset:[self offset] + bytesWritten];
                }
            }
        } break;
        case NSStreamEventErrorOccurred: {
            [self onStreamError:[aStream streamError]];
        } break;
        case NSStreamEventHasBytesAvailable:
        case NSStreamEventEndEncountered:
        default:
            assert(NO);     // should never happen for the output stream
            break;
    }
}

// A category on NSStream that provides a nice, Objective-C friendly way to create
// bound pairs of streams.  Adapted from the SimpleURLConnections sample code.
- (void)createBoundInputStream:(NSInputStream **)inputStreamPtr
                  outputStream:(NSOutputStream **)outputStreamPtr
                    bufferSize:(NSUInteger)bufferSize
{
    CFReadStreamRef     readStream;
    CFWriteStreamRef    writeStream;

    assert( (inputStreamPtr != NULL) || (outputStreamPtr != NULL) );

    readStream = NULL;
    writeStream = NULL;

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
    CFStreamCreateBoundPair(
                            NULL,
                            ((inputStreamPtr  != nil) ? &readStream : NULL),
                            ((outputStreamPtr != nil) ? &writeStream : NULL),
                            (CFIndex) bufferSize
                            );
    //    }

    if (inputStreamPtr != NULL) {
        *inputStreamPtr  = CFBridgingRelease(readStream);
    }
    if (outputStreamPtr != NULL) {
        *outputStreamPtr = CFBridgingRelease(writeStream);
    }
}



@end
