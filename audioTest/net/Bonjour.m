//
//  Bonjour.m
//  audioTest
//
//  Created by yogi on 6/20/20.
//  Copyright © 2020 zed. All rights reserved.
//


/*
 the old thoughts:
 the key point: when to invite a peer.
 I saw 7 peers somewhere as maximum.
 we invite a peer, and then check
 #1 whether he has what I am looking for.
 #2 does he serve as a router for message delivery? if yes, forward some messages
 #3 whether he has what I want to advertise
 
 
 new thoughts:
 Bonjour only serves to find the connect points.
 nothing else.
 
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIDevice.h>
#import "Bonjour.h"
#import "NSData+Hex.h"


@interface WrapperService:NSObject
@property (nonatomic,strong) NSNetService *service;

@property (nonatomic,strong) void (^result)(NSDictionary<NSString *, NSNumber *> *errorDict);

@end

@interface  WrapperBrowser : NSObject<NSNetServiceBrowserDelegate>

@property (nonatomic,strong) NSString *type; //the one we are browsing.
@property (nonatomic,strong) NSNetServiceBrowser *  browser;
@property (nonatomic,strong) void (^result)(NSDictionary<NSString *, NSNumber *> *errorDict);

@end
@interface Bonjour()<NSNetServiceDelegate>
+(WrapperService *)searchPeerByService:(NSNetService *)service;
+(WrapperService *)searchLocalService:(NSNetService *)service;
@end


static Bonjour *p2p;
static NSMutableArray<WrapperService *> *peers=nil;
static NSMutableArray<WrapperService *> *servicesLocal=nil;
static NSMutableArray<WrapperBrowser *> *browsers=nil;
static BOOL test=YES;



@implementation WrapperService


@end

@implementation WrapperBrowser

-(WrapperBrowser *)init{
    self=[super init];
    if(self){
    _browser=nil;
    _type=nil;
    _result=nil;
    }
    return self;
}

//@protocol NSNetServiceBrowserDelegate <NSObject>
//@optional

/* Sent to the NSNetServiceBrowser instance's delegate before the instance begins a search. The delegate will not receive this message if the instance is unable to begin a search. Instead, the delegate will receive the -netServiceBrowser:didNotSearch: message.
 */
- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser{
    NSLog(@"browser will search:%d %d %@",browser ==_browser, [browser isEqual:_browser],_type);
}

/* Sent to the NSNetServiceBrowser instance's delegate when the instance's previous running search request has stopped.
 */
- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser{
    NSLog(@"browser did stop search");
}

/* Sent to the NSNetServiceBrowser instance's delegate when an error in searching for domains or services has occurred. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants). It is possible for an error to occur after a search has been started successfully.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary<NSString *, NSNumber *> *)errorDict{
    NSLog(@"browser did not search");
    //    assert(browser == self.browser);
#pragma unused(browser)
    assert(errorDict != nil);
#pragma unused(errorDict)
    //    assert(NO);         // The usual reason for us not searching is a programming error.
    for(WrapperBrowser *wb in browsers){
        if([wb.browser isEqual:browser]){
            wb.result(errorDict);
            return;
        }
    }
    
}

/* Sent to the NSNetServiceBrowser instance's delegate for each domain discovered. If there are more domains, moreComing will be YES. If for some reason handling discovered domains requires significant processing, accumulating domains until moreComing is NO and then doing the processing in bulk fashion may be desirable.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing{
    NSLog(@"browser did find domain:%@",domainString);
}

/* Sent to the NSNetServiceBrowser instance's delegate for each service discovered. If there are more services, moreComing will be YES. If for some reason handling discovered services requires significant processing, accumulating services until moreComing is NO and then doing the processing in bulk fashion may be desirable.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing{
    NSLog(@"browser did find service:%@",service);
    //found self: browser did find service:<NSNetService 0x600003048460> local. _witap2._tcp. iPhone 11 -1
    assert([_browser isEqual:browser]);
    _result(nil);
    
    //    assert(browser == _browser);
    assert(service != nil);
    
    // Add the service to our array (unless its our own service).
    
    //    if ( (self.localService == nil) || ! [self.localService isEqual:service] ) {
    //        [self.services addObject:service];
    //    }
    //    if([service isEqual:_server]){
    //        return;
    //    }
    //    [self.services addObject:service];
    WrapperService *peer=[Bonjour searchPeerByService:service];
    if(peer){
        NSLog(@"this should not happen, we found a newly found service peer");
    }else{
        peer=[[WrapperService alloc]init];
        peer.service=service;
        [peers addObject:peer];
        //        [peer connect];
        
        
        /*TODO:   do I need to resolve its address?
         and how can I receive TXTRecordData?
         */
        NSLog(@"addresses:%@",service.addresses);
        NSLog(@"hostname:%@",service.hostName);
        service.delegate=p2p;
        [service resolveWithTimeout:10];
        [service startMonitoring];
    }
    
}

/* Sent to the NSNetServiceBrowser instance's delegate when a previously discovered domain is no longer available.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveDomain:(NSString *)domainString moreComing:(BOOL)moreComing{
    NSLog(@"browser did remove domain");
}

/* Sent to the NSNetServiceBrowser instance's delegate when a previously discovered service is no longer published.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing{
    NSLog(@"browser did remove service:%@",service);
    //    assert(browser == self.browser);
#pragma unused(browser)
    assert(service != nil);
    
    // Remove the service from our array (assume it's there, of course).
    
    //    if ( (self.localService == nil) || ! [self.localService isEqual:service] ) {
    //        [self.services removeObject:service];
    //    }
    //    if([service isEqual:_server]) return;
    WrapperService *peer=[Bonjour searchPeerByService:service];
    if(peer){
        [peers removeObject:peer];
    }else{
        peer=[Bonjour searchLocalService:service];
        if(peer)
            [servicesLocal removeObject:peer];
    }
    
    
    // Only update the UI once we get the no-more-coming indication.
    
    //    if ( ! moreComing ) {
    //        [self sortAndReloadTable];
    //    }
    
}


@end



@implementation Bonjour

+(void)publish:(NSString *)serviceTypeBonjour pkType:(int)pkType pk:(NSString *)pk host:(NSString *)host port:(int)port
        result:(void (^)(NSDictionary<NSString *, NSNumber *> *errorDict))result{
    [Bonjour init_s];
    
    WrapperService *ws=[[WrapperService alloc]init];
    ws.result=result;
    NSString *serviceName;
    if(test){
        serviceName=[UIDevice currentDevice].name;
    }else{
        uint8_t randomName[16];
        arc4random_buf((void *)randomName, sizeof(randomName));
        serviceName=[[[NSData alloc]initWithBytes:randomName length:sizeof(randomName)] toHex];
    }
    NSNetService *service= [[NSNetService alloc] initWithDomain:@"local." type:serviceTypeBonjour name:serviceName port:port];
    ws.service=service;
    [servicesLocal addObject:ws];
    service.includesPeerToPeer = YES;
    service.delegate=p2p;
    
    uint8_t one=1;
    NSData *d_version=[[NSData alloc]initWithBytes:&one length:1];
    NSData *d_pkType=[[NSData alloc]initWithBytes:&pkType length:1];
    uint8_t nonce[32];
    //    for(int i=0;i<sizeof(nonce);i++){
    //       nonce[i]=arc4random_uniform(256);
    //    }
    arc4random_buf((void *)nonce, sizeof(nonce));
    NSDictionary *dict=[[NSDictionary alloc]initWithObjectsAndKeys:d_version,@"version",
                        d_pkType,@"pkType",
                        [pk dataUsingEncoding:NSASCIIStringEncoding],@"pk",
                        [[NSData alloc]initWithBytes:nonce length:sizeof(nonce)],@"nonce",
                        nil];
    NSData *dFinal=[NSNetService dataFromTXTRecordDictionary:dict];
    if(dFinal){}else NSLog(@"failed to prepare TXTRecord");
    service.TXTRecordData=dFinal;
    [service publishWithOptions:NSNetServiceListenForConnections];
    //                NSLog(@"server is on port:%@",port);
}

+(void)startSearch:(NSString *)serviceTypeBonjour
            result:(void (^)(NSDictionary<NSString *, NSNumber *> *errorDict))result{
    //do I wait till our server indeed published?
    /*
     This can be an explicit domain name or it can contain the generic local domain name, @"local." (note the trailing period, which indicates an absolute name).
     */
    NSNetServiceBrowser *browser=[[NSNetServiceBrowser alloc] init];
    WrapperBrowser *wb=[[WrapperBrowser alloc]init];
    wb.browser=browser; wb.type=serviceTypeBonjour;
    wb.result=result;
    [browsers addObject:wb];
    browser.includesPeerToPeer = YES;
    browser.delegate=wb;
    //            self.type = kWiTapBonjourType;
    [browser searchForServicesOfType:serviceTypeBonjour inDomain:@"local."];
/* the command line shows the service is published
 % dns-sd -B _road._tcp local.
 % dns-sd -B _road._tcp. local.
 the above 2 command lines give same results:
 Browsing for _road._tcp..local.
 DATE: ---Sun 21 Jun 2020---
  0:11:31.247  ...STARTING...
 Timestamp     A/R    Flags  if Domain               Service Type         Instance Name
 0:11:31.250  Add        3   1 local.               _road._tcp.          iPhone 11
 0:11:31.250  Add        3   6 local.               _road._tcp.          iPhone 11
 0:11:31.250  Add        3   7 local.               _road._tcp.          iPhone 11
 0:11:31.250  Add        3   7 local.               _road._tcp.          阿豪 的 iPad
 0:11:31.250  Add        2   6 local.               _road._tcp.          阿豪 的 iPad

 
  but this browser prints only "WillSearch", never "didFindService", why?
 
 */
    
}


//start searching Services, and notify the caller to connect
//stop searching
+(void)stopSearch:(NSString *)serviceTypeBonjour{
    
    
    
}


+(void)init_s{ //TODO: scan or startToScan is better name?
    if(p2p){}else{
        p2p=[[Bonjour alloc]init];
        peers=[[NSMutableArray alloc]init];
        servicesLocal=[[NSMutableArray alloc]init];
        browsers=[[NSMutableArray alloc]init];
    }
}
-(Bonjour *)init{
    self=[super init];
    if(self){
        //        myname=[UIDevice currentDevice].name; //TODO: I should use some random string.
        //        pkCurve25519_s=[@"阿豪 的 iPad" isEqualToString:myname]?@"12345":@"67890";
        // Do any additional setup after loading the view.
        //        if([@"阿豪 的 iPad" isEqualToString:myname]){
        //            _isServerStarted = YES;
        //        }else{
        //            _server=nil;
        //            _isServerStarted = NO;
        //        }
        
    }
    return self;
}

+(WrapperService *)searchPeerByService:(NSNetService *)service{
    for(WrapperService *p in peers){
        //Be noted, the real ID is the certificates which I am not using, so the real ID is pkCurve25519.
        if(p.service==service){
            NSLog(@"search:match peer with \"service\"");
            return p;
        }
    }
    return nil;
}


//@protocol NSNetServiceDelegate <NSObject>
//@optional

/* Sent to the NSNetService instance's delegate prior to advertising the service on the network. If for some reason the service cannot be published, the delegate will not receive this message, and an error will be delivered to the delegate via the delegate's -netService:didNotPublish: method.
 */
- (void)netServiceWillPublish:(NSNetService *)sender{
    //    assert(sender==_server);
    NSLog(@"net service will publish");
    
}

/* Sent to the NSNetService instance's delegate when the publication of the instance is complete and successful.
 */
- (void)netServiceDidPublish:(NSNetService *)sender{
    //    assert(sender==_server);
    
    NSLog(@"net service did publish, port#:%ld, addresses:%@ %@",(long)sender.port,sender.addresses,sender);
#pragma unused(sender)
    WrapperService *oservice=[Bonjour searchLocalService:sender];
    oservice.result(nil);
    
    //    self.registeredName = self.server.name;
    //    if (self.picker != nil) {
    //        // If our server wasn't started when we brought up the picker, we
    //        // left the picker stopped (because without our service name it can't
    //        // filter us out of its list).  In that case we have to start the picker
    //        // now.
    //
    //        [self startPicker];
    //    }
    //
    
}

/* Sent to the NSNetService instance's delegate when an error in publishing the instance occurs. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants). It is possible for an error to occur after a successful publication.
 */
- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary<NSString *, NSNumber *> *)errorDict{
    /*
     This is called when the server stops of its own accord.  The only reason
     that might happen is if the Bonjour registration fails when we reregister
     the server, and that's hard to trigger because we use auto-rename.  I've
     left an assert here so that, if this does happen, we can figure out why it
     happens and then decide how best to handle it.
     
     */
    NSLog(@"net service did not publish:%@",errorDict);
    //I got -72004: NSNetServicesBadArgumentError
    //    assert(sender==_server);
#pragma unused(sender)
#pragma unused(errorDict)
    WrapperService *oservice=[Bonjour searchLocalService:sender];
    oservice.result(errorDict);
    //    assert(NO);
    
}

/* Sent to the NSNetService instance's delegate prior to resolving a service on the network. If for some reason the resolution cannot occur, the delegate will not receive this message, and an error will be delivered to the delegate via the delegate's -netService:didNotResolve: method.
 */
- (void)netServiceWillResolve:(NSNetService *)sender{
    NSLog(@"net service will resolve");
    //    assert(sender==_server);
    
}

/* Sent to the NSNetService instance's delegate when one or more addresses have been resolved for an NSNetService instance. Some NSNetService methods will return different results before and after a successful resolution. An NSNetService instance may get resolved more than once; truly robust clients may wish to resolve again after an error, or to resolve more than once.
 */
- (void)netServiceDidResolveAddress:(NSNetService *)sender{
    NSLog(@"net service did resolve address");
//    assert(NO);
    //TODO: here the job of Bonjour is done, notify the caller to connect
    
    //    assert(sender==_service);
    //    unsigned long count=sender.addresses.count;
    //    NSLog(@"peer did resolve, port:%ld addresses:%lu",(long)sender.port,count);
    //    for(NSData *data in sender.addresses){
    //        struct sockaddr *ps=(struct sockaddr *)data.bytes;
    //
    //    }
    
    
}

/* Sent to the NSNetService instance's delegate when an error in resolving the instance occurs. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants).
 */
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary<NSString *, NSNumber *> *)errorDict{
    NSLog(@"net service did not resolve");
    //    assert(sender==_server);
    
}

/* Sent to the NSNetService instance's delegate when the instance's previously running publication or resolution request has stopped.
 */
- (void)netServiceDidStop:(NSNetService *)sender{
    NSLog(@"net service did stop");
    //    assert(sender==_server);
    
}

/* Sent to the NSNetService instance's delegate when the instance is being monitored and the instance's TXT record has been updated. The new record is contained in the data parameter.
 */
- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data{
    //    assert(sender==_server);
    if([Bonjour searchLocalService:sender]){
        NSLog(@"net service did update txt record data");
        return;
    }
    NSLog(@"peer did update TXTRecord Data:%@",data);
    
}


/* Sent to a published NSNetService instance's delegate when a new connection is
 * received. Before you can communicate with the connecting client, you must -open
 * and schedule the streams. To reject a connection, just -open both streams and
 * then immediately -close them.
 
 * To enable TLS on the stream, set the various TLS settings using
 * kCFStreamPropertySSLSettings before calling -open. You must also specify
 * kCFBooleanTrue for kCFStreamSSLIsServer in the settings dictionary along with
 * a valid SecIdentityRef as the first entry of kCFStreamSSLCertificates.
 */
- (void)netService:(NSNetService *)sender didAcceptConnectionWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream API_AVAILABLE(macos(10.9), ios(7.0), watchos(2.0), tvos(9.0)){
    //    assert(NO);
    NSLog(@"net serivice did accept connection with input stream, but which peer");
    // Due to a bug <rdar://problem/15626440>, this method is called on some unspecified
    // queue rather than the queue associated with the net service (which in this case
    // is the main queue).  Work around this by bouncing to the main queue.
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
#pragma unused(sender)
        assert(inputStream != nil);
        assert(outputStream != nil);
        
        //        assert( (self.inputStream != nil) == (self.outputStream != nil) );      // should either have both or neither
        
        if (YES) { //self.inputStream != nil
            // We already have a game in place; reject this new one.
            [inputStream open];
            [inputStream close];
            [outputStream open];
            [outputStream close];
        } else {
            // Start up the new game.  Start by deregistering the server, to discourage
            // other folks from connecting to us (and being disappointed when we reject
            // the connection).
            
            //            [self.server stop];
            //            self.isServerStarted = NO;
            //            self.registeredName = nil;
            
            // Latch the input and output sterams and kick off an open.
            
            //            self.inputStream  = inputStream;
            //            self.outputStream = outputStream;
            //
            //            [self openStreams];
        }
    }];
    
}
+(WrapperService *)searchLocalService:(NSNetService *)service{
    for(WrapperService *ws in servicesLocal){
        if([ws.service isEqual:service])
            return ws;
    }
    return nil;
}



@end
