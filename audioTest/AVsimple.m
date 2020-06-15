//
//  AVsimple.m
//  audioTest
//
//  Created by yogi on 5/26/20.
//  Copyright © 2020 zed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIDevice.h>
#import "AVsimple.h"
#import "SocketStreams.h"

//@interface AVsimple(private)
//
//
//
//@end


static AVsimple *one=nil;

@implementation AVsimple{
    CGFloat playVolume; //do not access it directly, use changePlayVolume
    
    long durationRecord; //in milliseconds.
    BOOL isRecording;
}

+(AVsimple *)singlenton{
    if(one){}else{
        one=[[AVsimple alloc]init];
    }
    return one;
}
-(AVAudioSession *)session{
    return AVAudioSession.sharedInstance;
}
-(AVsimple *)init{
    self=[super init];
    if(self){
        //        _ss=nil;
        _player=nil;
        _recorder=nil;
        _fnPlay=nil;
        _pathPlay=nil;
        _fnRecord=nil;
        _pathRecord=nil;
        //self->
        playVolume=0.2; //TODO: cross session, how to save to to disk.
        _webviewjs=nil;
        _cocosappjs=nil;
        //        AVAudioSession *session =[self session];
        // Configure the audio session for movie playback
        [self setSessionToPlay];
        //        NSError *error;
        //        if (@available(iOS 10.0, *)) {
        //            [session setCategory:AVAudioSessionCategoryPlayAndRecord//AVAudioSessionCategoryPlayback,
        //                            mode:AVAudioSessionModeVoiceChat //AVAudioSessionModeMoviePlayback,
        //                         options:AVAudioSessionCategoryOptionMixWithOthers
        //                           error:&error];
        //        } else {
        //            // Fallback on earlier versions
        //            [session setCategory:AVAudioSessionCategoryPlayAndRecord  withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&error]; //ios 6
        //            //            session.mode=AVAudioSessionModeVoiceChat;
        //        }
        //        if(error){
        //            NSLog(@"failed to init audio session:%@",error);
        //        }
        //        _errorInit=nil;
        //        self.errorInit=error;
    }
    return self;
}


//-(AVsimple *)config:(NSString *)dir{
//    self.dir=dir;
//    return self;
//}


-(void)eval:(NSString *)js {
    if (self.webviewjs) {
        self.webviewjs(js);
    } else if(self.cocosappjs) {
        self.cocosappjs(js);
    }
}


-(void)changePlayVolume:(CGFloat)volume{
    self->playVolume=volume;
    if(self.player){
        self.player.volume=volume;
    }
    //TODO: the volume preset.  save volume to across session.
}
-(void)play:(NSString *)fn  //autoStart:(BOOL)autoStart
 startPoint:(int)startPoint{
    BOOL autoStart=startPoint>=0;
    NSString *path=//fn; //
    [NSString stringWithFormat:@"%@%@",self.dir,fn];
    NSLog(@"%d path:%@",autoStart,path);
    NSFileManager *fm=NSFileManager.defaultManager;
    int ireason=0;
    NSString *sreason=nil;
    if([fm fileExistsAtPath:path]){
        self.fnPlay=fn;
        self.pathPlay=path;
//#ifdef MRC
//        [self->fnPlay retain]; //passed down, so we need this.
////        [self->pathPlay retain]; //this one, we do not need it?
//#endif
        NSURL *url=[NSURL fileURLWithPath:path];
        NSError *error;
        self.player=[[AVAudioPlayer alloc]initWithContentsOfURL:url //fileTypeHint:<#(NSString * _Nullable)#>
                                                          error:&error];
        if(error){
            ireason=-1;
            sreason=[NSString stringWithFormat:@"failed to deal with file %@:%@",fn,error];
        }else{
            self.player.delegate=self;
            self.player.volume=self->playVolume;
            BOOL tf;
            BOOL playing;//NSString *state;
            [self setSessionToPlay];
            if(autoStart){
                if(startPoint>0)
                    self.player.currentTime=startPoint/1000;
                tf=[self.player play];
                playing=YES; //state=@"started";
            }else {
                tf=[self.player prepareToPlay]; //TODO: do I have to change session before this?
                playing=NO; //state=@"prepared";
            }
            if(tf){
                [self sendInfoPlay:playing];
            }else{
                ireason=-1;
                sreason=[NSString stringWithFormat:@"failed to init player for %@",fn];
            }
        }
    }else{
        ireason=-1;
        sreason=[NSString stringWithFormat:@"fileNotFound:%@",fn];
    }
    if(ireason!=0){
        NSLog(@"%@",sreason);
        [self sendError:YES ireason:ireason sreason:sreason]; //TODO: move to the end of this method
    }
}
-(void)sendInfoPlay:(BOOL)playing{
    int current_i=self.player.currentTime*1000;
    int duration_i=self.player.duration*1000;
    NSString *current=[NSString stringWithFormat:@"%d",current_i];
    NSString *duration=[NSString stringWithFormat:@"%d",duration_i];
    NSMutableDictionary<NSString *,NSString *> *dict =[[NSMutableDictionary alloc]initWithObjectsAndKeys:current,@"current",
                                                       duration,@"duration",
                                                       self.fnPlay,@"fn",
                                                       playing?@"playing":@"prepared",@"state", nil];
    [self sendJSON:YES ojson:dict];
}

-(void)pause{
    //TODO: are we in playing state
    [self.player pause];
    [self sendInfoPlay:NO];
}

-(void)resume{
    //TODO: are we in playing state
    BOOL tf=[self.player play];
    if(tf){
        [self sendInfoPlay:YES];
    }else{
        [self sendError:YES ireason:-1 sreason:@"failed to resume"];// NSLog(@"failed to resume");
    }
}
-(void)setSessionToPlay{
    AVAudioSession *session=[self session];
    NSError *error;
    BOOL tf=[session setCategory:AVAudioSessionCategoryPlayback
                            mode:AVAudioSessionModeDefault //AVAudioSessionModeVoiceChat //AVAudioSessionModeMoviePlayback,
                         options:AVAudioSessionCategoryOptionMixWithOthers
                           error:&error];
    if(tf){}else{
        NSLog(@"failed to set session to play:%@",error);
    }
}
-(void)setSessionToRecord{
    AVAudioSession *session=[self session];
    NSError *error;
    BOOL tf=[session setCategory:AVAudioSessionCategoryRecord//AVAudioSessionCategoryPlayback,
                            mode:AVAudioSessionModeDefault //AVAudioSessionModeVoiceChat //AVAudioSessionModeMoviePlayback,
                         options:0
                           error:&error];
    if(tf){}else{
        NSLog(@"failed to set session to record:%@",error);
    }
}

//pos is in millisecond
-(void)seekToPlay:(NSTimeInterval)pos{
    self.player.currentTime=pos/1000;
    BOOL tf=[self.player play];
    if(tf){
        [self sendInfoPlay:YES];
    }else{
        NSString *msg=[NSString stringWithFormat:@"failed to start playing for %@",self.fnPlay];
        NSLog(@"%@",msg);
        [self sendError:YES ireason:-1 sreason:msg];
    }
}
-(void)sendError:(BOOL)isPlay ireason:(int)ireason sreason:(NSString *)sreason{
    NSMutableDictionary<NSString *,NSString *> *dict =[[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSString stringWithFormat:@"%d",ireason],@"ireason",sreason,@"sreason",@"error",@"state", nil];
    [self sendJSON:isPlay ojson:dict];
}

-(void)sendJSON:(BOOL)isPlay ojson:(NSMutableDictionary<NSString *,NSString *> *)ojson{
    NSString *fn=isPlay?@"bk.anysdk.onPlayInfo":@"bk.anysdk.onRecordInfo";
    //NSDictionary<NSString *,NSString *> *dict =@{@"ireason": [NSString stringWithFormat:@"%d",ireason],@"sreason": sreason};
    id data = [NSJSONSerialization dataWithJSONObject:ojson options:0 error:nil]; //NSJSONWritingPrettyPrinted
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *js=[NSString stringWithFormat:@"%@('%@')",fn, jsonString];
    NSLog(@"js:%@",js);
    [self eval:js];
}

//@protocol AVAudioPlayerDelegate <NSObject>
//@optional
/* audioPlayerDidFinishPlaying:successfully: is called when a sound has finished playing. This method is NOT called if the player is stopped due to an interruption. */
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag{
    //    NSLog(@"play finished successfully:%d duration:%f %f",flag, self.player.currentTime,self.player.duration);
    //    NSString *msg=[NSString stringWithFormat:@"done play %@",fnPlay];
    //    NSLog(@"%@",msg);
    //    [self sendError:0 sreason:msg];
    NSMutableDictionary<NSString *,NSString *> *dict =[[NSMutableDictionary alloc] initWithObjectsAndKeys:self.fnPlay,@"fn",@"done",@"state", nil];
    [self sendJSON:YES ojson:dict];
}

/* if an error occurs while decoding it will be reported to the delegate. */
- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError * __nullable)error{
    NSString *msg=[NSString stringWithFormat:@"error play %@:%@",self.fnPlay,error];
    NSLog(@"%@",msg);
    [self sendError:YES ireason:-1 sreason:msg];
}

//#if TARGET_OS_IPHONE

/* AVAudioPlayer INTERRUPTION NOTIFICATIONS ARE DEPRECATED - Use AVAudioSession instead. */

/* audioPlayerBeginInterruption: is called when the audio session has been interrupted while the player was playing. The player will have been paused. */
//- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player NS_DEPRECATED_IOS(2_2, 8_0){
//
//}

/* audioPlayerEndInterruption:withOptions: is called when the audio session interruption has ended and this player had been interrupted while playing. */
/* Currently the only flag is AVAudioSessionInterruptionFlags_ShouldResume. */
//- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player withOptions:(NSUInteger)flags NS_DEPRECATED_IOS(6_0, 8_0);

//- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player withFlags:(NSUInteger)flags NS_DEPRECATED_IOS(4_0, 6_0);

/* audioPlayerEndInterruption: is called when the preferred method, audioPlayerEndInterruption:withFlags:, is not implemented. */
//- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player NS_DEPRECATED_IOS(2_2, 6_0);



-(void)record:(NSString *)fn duration:(long)d{
    //TODO: To get all encodable formats, query kAudioFormatProperty_EncodeFormatIDs at runtime.
    if(isRecording){
        if([self.fnRecord isEqualToString:fn]){
            [self sendInfoRecord];
        }else{
            [self sendError:NO ireason:-1 sreason:[NSString stringWithFormat:@"call stop and then call record again. is recording to %@",self.fnRecord]];
        }
        return;
    }
    self.fnRecord=fn;
    isRecording=YES;
    NSString *path=[NSString stringWithFormat:@"%@%@",self.dir,fn];
    self.pathRecord=path;
//#ifdef MRC
//    [self->fnRecord retain];
//    [self->pathRecord retain];
//#endif
    NSURL *url=[NSURL fileURLWithPath:path];
    //    NSDictionary<NSString *,id> *settings=[[NSDictionary alloc] initWithObjectsAndKeys:
    //                                           [NSNumber numberWithInt:kAudioFormatMPEG4AAC], AVFormatIDKey,
    //                                           [NSNumber numberWithInt:16000],AVSampleRateKey,
    //                                           [NSNumber numberWithInt:1],AVNumberOfChannelsKey,
    //                                           [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,
    //                                           [NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,
    //                                           [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,nil];
    NSDictionary<NSString *,id> *settings=[[NSDictionary alloc] initWithObjectsAndKeys:
                                           [NSNumber numberWithInt:kAudioFormatMPEG4AAC], AVFormatIDKey,
                                           [NSNumber numberWithInt:16000],AVSampleRateKey,
                                           [NSNumber numberWithInt:2],AVNumberOfChannelsKey,
                                           [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,
                                           [NSNumber numberWithBool:YES],AVLinearPCMIsBigEndianKey,
                                           [NSNumber numberWithBool:YES],AVLinearPCMIsFloatKey,nil];
    NSError *error;
    self.recorder=[[AVAudioRecorder alloc]initWithURL:url
                                             settings:settings
                                                error:&error];
    CGFloat gain = 1;
    AVAudioSession *session=[self session];
    if (YES) { //session.isInputGainSettable
        BOOL success = [session setInputGain:gain error:&error];
        if (success){}else{ //error handling
            NSLog(@"failed to set input gain:%@",error);
        }
    } else {
        NSLog(@"input gain is not settable");
    }
    //with the following setting, the recorded volume is higher.
    [self setSessionToRecord];
    int ireason=0;
    NSString *sreason;
    if(error){
        ireason=-1;
        sreason=[NSString stringWithFormat:@"failed to init recorder for %@:%@",fn,error];
    }else{
        self.recorder.delegate=self;
        durationRecord=d;
        double duration=d;
        duration/=1000;
        if(duration<5) duration=5; //at least 5 seconds.
        BOOL tf=[self.recorder recordForDuration:duration];
        if(tf){
            [self sendInfoRecord];
        }else {
            ireason=-1;
            sreason=@"failed to start recording";
        }
    }
    if(ireason!=0){
        //        NSLog(sreason);
        [self sendError:NO ireason:ireason sreason:sreason];
    }
}
-(void)stopRecord:(NSString *)fn{
    if([self.fnRecord isEqualToString:fn]){
        isRecording=NO;
        [self.recorder stop]; //the delegate will be called.
        NSLog(@"successfully stopped recording %@",fn);
    }
}
//this is called when recorder is successfully started.
-(void)sendInfoRecord{ //:(BOOL)recording
    //    int current_i=self.player.currentTime*1000;
    //    int duration_i=self.player.duration*1000;
    //    NSString *current=[NSString stringWithFormat:@"%d",current_i];
    NSString *duration=[NSString stringWithFormat:@"%ld",durationRecord];
    NSMutableDictionary<NSString *,NSString *> *dict =[[NSMutableDictionary alloc]initWithObjectsAndKeys://current,@"current",
                                                       duration,@"duration",
                                                       self.pathRecord,@"fn",
                                                       @"recording",//recording?@"playing":@"prepared",
                                                       @"state", nil];
    [self sendJSON:NO ojson:dict];
}

//@protocol AVAudioRecorderDelegate <NSObject>
//@optional

/* audioRecorderDidFinishRecording:successfully: is called when a recording has been finished or stopped. This method is NOT called if the recorder is stopped due to an interruption. */
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag{
    isRecording=NO;
    [self setSessionToPlay];
    NSMutableDictionary<NSString *,NSString *> *dict =[[NSMutableDictionary alloc] initWithObjectsAndKeys:self.pathRecord, //fnRecord, //
                                                       @"fn",
                                                       @"stopped",@"state", nil];
    [self sendJSON:NO ojson:dict];
}

/* if an error occurs while encoding it will be reported to the delegate. */
- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError * __nullable)error{
    isRecording=NO;
    [self setSessionToPlay];
    NSString *msg=[NSString stringWithFormat:@"error record %@:%@",self.fnRecord,error];
    NSLog(@"%@",msg);
    [self sendError:NO ireason:-1 sreason:msg];
}

//#if TARGET_OS_IPHONE

/* AVAudioRecorder INTERRUPTION NOTIFICATIONS ARE DEPRECATED - Use AVAudioSession instead. */

/* audioRecorderBeginInterruption: is called when the audio session has been interrupted while the recorder was recording. The recorded file will be closed. */
//- (void)audioRecorderBeginInterruption:(AVAudioRecorder *)recorder NS_DEPRECATED_IOS(2_2, 8_0);

/* audioRecorderEndInterruption:withOptions: is called when the audio session interruption has ended and this recorder had been interrupted while recording. */
/* Currently the only flag is AVAudioSessionInterruptionFlags_ShouldResume. */
//- (void)audioRecorderEndInterruption:(AVAudioRecorder *)recorder withOptions:(NSUInteger)flags NS_DEPRECATED_IOS(6_0, 8_0);

//- (void)audioRecorderEndInterruption:(AVAudioRecorder *)recorder withFlags:(NSUInteger)flags NS_DEPRECATED_IOS(4_0, 6_0);

/* audioRecorderEndInterruption: is called when the preferred method, audioRecorderEndInterruption:withFlags:, is not implemented. */
//- (void)audioRecorderEndInterruption:(AVAudioRecorder *)recorder NS_DEPRECATED_IOS(2_2, 6_0);


-(void)delete:(NSString *)fn{
    //TODO: delete a file
    NSString *path=[NSString stringWithFormat:@"%@%@",self.dir,fn];
    NSFileManager *fm=[NSFileManager defaultManager];
    if([fm fileExistsAtPath:path]){
        NSError *error;
        BOOL tf=[fm removeItemAtPath:path error: &error];
        if(tf){}else{
            NSLog(@"failed to delete %@",path);
        }
    }
    
    
}

-(void)setDirParent:(NSString *)dirWritable{ //with ending "/"
    self.dir=[NSString stringWithFormat:@"%@voicemsgs/",dirWritable];
    NSFileManager *fm=[NSFileManager defaultManager];
    NSError *error;
    if([fm fileExistsAtPath:self.dir]){}else{
        BOOL tf=[fm createDirectoryAtPath:self.dir withIntermediateDirectories:YES attributes:nil error:&error];
        if(tf){}else{
            NSLog(@"failed to create dir for voice msgs:%@ reason:%@",self.dir,error);
        }
    }
}

-(void)listFilesAudio{
    NSFileManager *fm=[NSFileManager defaultManager];
    NSError *error;
    NSArray<NSString *> *files=[fm contentsOfDirectoryAtPath:self.dir error:&error];
    if(files){
        NSLog(@"array is jsonobj? %d",[NSJSONSerialization isValidJSONObject:files]);
        //    for(NSString *file in files){
        //        NSLog(@"file:%@",file);
        //    }
        //    self.files=files;
        //    return YES;
        
        //        NSMutableDictionary<NSString *,NSString *> *dict =[[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSString stringWithFormat:@"%d",ireason],@"ireason",sreason,@"sreason", nil];
        //NSDictionary<NSString *,NSString *> *dict =@{@"ireason": [NSString stringWithFormat:@"%d",ireason],@"sreason": sreason};
        id data = [NSJSONSerialization dataWithJSONObject:files options:0 error:nil]; //NSJSONWritingPrettyPrinted
        NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSString *js=[NSString stringWithFormat:@"bk.anysdk.allFilesAudio('%@')", jsonString];
        NSLog(@"js:%@",js);
        [self eval:js];
    }else{
        //    NSLog(@"failed to fetch list:%@",error);
        //    return NO;
    }
    
    
    
    
}
@end
