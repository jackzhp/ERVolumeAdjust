//
//  AVsimple.h
//  audioTest
//
//  Created by yogi on 5/26/20.
//  Copyright © 2020 zed. All rights reserved.
//

#ifndef AVsimple_h
#define AVsimple_h
#import <AVFoundation/AVFoundation.h>

//#import "AVFoundation/AVAudioSession.h"
//#import "AVFoundation/AVAudioPlayer.h"
//#import "AVFoundation/AVAudioRecorder.h"
//#import <WebKit/WKWebView.h>
@class SocketStreams;
@interface AVsimple: NSObject<AVAudioPlayerDelegate, AVAudioRecorderDelegate>

@property (strong, nonatomic) AVAudioSession *as;
@property (strong, nonatomic) AVAudioPlayer *player;
@property (strong, nonatomic) AVAudioRecorder *recorder;
@property (strong, nonatomic) NSString *dir; //where those voice file stored.
@property (strong, nonatomic) NSError *errorInit;
//@property (weak, nonatomic) WKWebView *wkWebView;
@property (strong,nonatomic) void (^webviewjs)(NSString *js); //with priority
@property (strong,nonatomic) void (^cocosappjs)(NSString *js);

//@property (weak, nonatomic) SocketStreams *ss; //they are all in sss, so this weak is OK.
//do not keep it here.

@property (copy,nonatomic) NSString *fnPlay;
@property (strong,nonatomic) NSString *pathPlay;
@property (copy,nonatomic) NSString *fnRecord;
@property (strong,nonatomic) NSString *pathRecord;


//-(AVsimple *)init;

//-(AVsimple *)initWithDir:(NSString *)dir;
//-(void)play:(NSString *)fn autoStart:(BOOL)autoStart startPoint:(int)startPoint; //audoStart or not
-(void)play:(NSString *)fn startPoint:(int)startPoint; //audoStart or not
-(void)pause;
-(void)resume;
-(void)seekToPlay:(NSTimeInterval)pos;
-(void)changePlayVolume:(CGFloat)volume;
+(AVsimple *)singlenton;

-(void)record:(NSString *)fn duration:(long)d;
-(void)stopRecord:(NSString *)fn;

-(void)delete:(NSString *)fn;
-(void)setDirParent:(NSString *)dirWritable;
-(void)listFilesAudio;

@end


#endif /* AVsimple_h */
