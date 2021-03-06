//
//  ViewController.m
//  audioTest
//
//  Created by yogi on 5/23/20.
//  Copyright © 2020 zed. All rights reserved.
//

#import "ViewController.h"
//#import "AVFoundation/AVAudioSession.h"
#import "AVsimple.h"
#import "SocketStreams.h"
#import "SocketServer.h"
#import "Bonjour.h"

@interface ViewController ()<UIDocumentPickerDelegate>

@end
static AVsimple *av; //where to keep this? AppDelegage.
NSString* fullpath;
NSString* dstPath;
NSString *dirVoiceMSGs;
//SocketStreams *ss; //as client //where to keep this? I will have many of them.

@implementation ViewController{
    BOOL isPlaying;
    long playStart;
    NSString *fnToPlay; //chosen, but not sent to the AVsimple
    NSString *pathToPlay;
    NSString *fnPlay;
    long durationPlay; //in milliseconds
    long startPoint; //seek start point
    
    BOOL isRecording;
    long recordStart;
    long durationRecord; //this might be different from durationMax4record
    NSString *fnRecord;
}

//-(id)init{
//    _files=[[NSMutableArray alloc]init];
//}




- (void)viewDidLoad {
    [super viewDidLoad];
    _durationMax4record=1000*60; //milliseconds
    _files=[[NSMutableArray alloc]init];
    _autoStart=YES;
    self.vAutoStart.on=_autoStart;
    // Do any additional setup after loading the view.
    //    [self.playVolume removeConstraints:self.playVolume.constraints];
    //    [self.playVolume setTranslatesAutoresizingMaskIntoConstraints:YES];
    //    self.playVolume.transform=CGAffineTransformRotate(self.playVolume.transform,270.0/180*M_PI);
    self.msgs.dataSource=self;
    self.msgs.delegate=self;
    
    //TODO: load files into self.files.
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString* dirWritable =[NSString stringWithFormat:@"%@/",documentsDirectory];
    
    
    av=[AVsimple singlenton];//[[AVsimple alloc]initWithDir:dir];
    [av setDirParent:dirWritable];
    av.webviewjs = ^(NSString *js){
        NSLog(@"js to webview:%@",js);
        NSRange r=[js rangeOfString:@"("];
        if(r.location==NSNotFound){
            NSLog(@"does not contain '('");
        }else{
            NSString *fn=[js substringToIndex:r.location];
            //            NSLog(@"fn:%@",fn);
            NSUInteger istart=r.location+2; //+1 is ''', +2 is '{'. inclusive so use +2
            r=[js rangeOfString:@")"];
            if(r.location==NSNotFound){
                NSLog(@"does not contain ')'");
            }else{
                NSUInteger iend=r.location-1; //-1 is ''', -2 is '}'. exclusive so use -1
                NSRange range=NSMakeRange(istart, iend-istart);
                NSString *json=[js substringWithRange:range];
                NSData* data=[json dataUsingEncoding:NSUTF8StringEncoding];
                NSError *error;
                //                NSInputStream *is=[[NSInputStream alloc]initWithData:data];
                //                NSJSONSerialization *o=[NSJSONSerialization JSONObjectWithStream:is options:0 error:&error];
                if(error){
                    NSLog(@"failed to parse json:%@",error);
                }else{
                    if([@"bk.anysdk.allFilesAudio" isEqualToString:fn]){
                        NSArray<NSString*> *array=[NSJSONSerialization JSONObjectWithData:(NSData *)data
                                                                                  options:0
                                                                                    error:&error];
                        if(NO){
                            //bk.anysdk.allFilesAudio('["1590715290.bin","1590710074.bin","1590709533.bin.m4a","273.bin","1590762022.bin","1590714900.bin.m4a","ca3cd36e-e121-4a85-9b3f-0daa92af7d54.2346f.mp3","1590708470.bin.m4a","1590761799.bin","1590712551.bin.m4a","1590713064.bin.m4a","1590762022.bin.m4a","1590706484.bin.m4a","1590719564.bin","1590707044.bin.m4a","1590707712.bin.m4a","1590719564.bin.m4a","771.mp3","1590761871.bin"]')
                            self.files=@[//@"1590715290.bin",@"1590710074.bin",
                                @"1590709533.bin.m4a",//@"273.bin","1590762022.bin",
                                @"1590714900.bin.m4a",//"ca3cd36e-e121-4a85-9b3f-0daa92af7d54.2346f.mp3",
                                @"1590708470.bin.m4a",//"1590761799.bin",
                                @"1590712551.bin.m4a",@"1590713064.bin.m4a",@"1590762022.bin.m4a",@"1590706484.bin.m4a",//"1590719564.bin",
                                @"1590707044.bin.m4a",@"1590707712.bin.m4a",@"1590719564.bin.m4a"];//,"771.mp3","1590761871.bin"
                        }else{
                            self.files=array;
                        }
                        [self.msgs reloadAllComponents];
                    }else{
                        NSDictionary<NSString*,NSString*> *dict=[NSJSONSerialization JSONObjectWithData:(NSData *)data
                                                                                                options:0
                                                                                                  error:&error];
                        if([@"bk.anysdk.onPlayInfo" isEqualToString:fn]){
                            [self onPlayInfo:dict]; //Method cache corrupted. This may be a message to an invalid object, or a memory error somewhere else.
                        }else if([@"bk.anysdk.onRecordInfo" isEqualToString:fn]){
                            [self onRecordInfo:dict];
                        } else {
                            NSLog(@"unknown fn:%@",fn);
                        }
                    }
                }
            }
        }
    };
    if(true){ //test part
        /* I should have a note here telling how did I put the file into the bundle.
         I have forgot it.
         
         now I copied the file into Assets.xcassets folder. can not find it.
         I copied to audioTest folder, and then in the building phases, add copy item. Yes. found it.
         */
        //copy an mp3 file to the dest
        //        NSString *fn=@"ca3cd36e-e121-4a85-9b3f-0daa92af7d54.2346f"; //.mp3
        //        NSString *type=@"mp3";
        NSString *fn=@"03896bf6_fa72_4ba9_b8fe_9e7938609783";//@"273"; //.mp3
        NSString *type=@"bin";
        NSFileManager *fm=NSFileManager.defaultManager;
        NSError *error;
        //        FileUtils* fu=FileUtils::getInstance();
        //        std::string dirApp=fu->getWritablePath();
        //        const char *dirApp2=dirApp.c_str();
        //    printf("dir path:%s\n",dirApp2);
        //    NSString *path=[NSString stringWithFormat:@"%@webviewTest.zip",dirWritable];
        //        NSString *path=[NSString stringWithFormat:@"%@test",dirWritable];
        //
        //NSString*
        fullpath = [NSBundle.mainBundle pathForResource:fn
                                                 ofType:type
                                            inDirectory:@"/"]; //  res
        BOOL e=[fm fileExistsAtPath:fullpath];
        NSLog(@"exists %@:%d",fullpath,e);
        if(e){
            //            NSString *zipFile=fullpath; //file.path;//i absoluteString];
            //NSString *
            dstPath=[NSString stringWithFormat:@"%@%@.%@",av.dir,fn,type];
            NSLog(@"dst file:%@",dstPath);
            e=[fm fileExistsAtPath:dstPath];
            if(e){}else{
                BOOL tf=[fm copyItemAtPath:fullpath toPath:dstPath error:&error];
                NSLog(@"copied %d %@",tf,error);
            }
            //            fnCurrent=@"ca3cd36e-e121-4a85-9b3f-0daa92af7d54.2346f.mp3"; //.mp3
        }
        
        BOOL connectAsClient=NO, publishBonjour=YES, searchBonjour=YES;
        NSString *host=@"192.168.254.139"; //ipad
        int port=11223;
        [SocketServer listen:YES ip:host port:port av:av];
        if(connectAsClient){
        dispatch_async(dispatch_get_main_queue(), ^{
            //host=@"172.217.26.132"; //www.google.com. yes, I can connect to it at port 80.
            NSString *hosttest=[NSString stringWithFormat:@"toLocal%@",host];
            SocketStreams *ss=[SocketStreams for_m:hosttest]; //ipad
            //        ss.dir=av.dir;
            ss.av=av;
            //        port=80;
            [ss connect:host port:port];
            //            av.ss=ss;
        });
        }
        NSString *serviceTypeBonjour=@"_road._tcp.";//@"_road._udp";
        if(publishBonjour){
            int pkType=1;
            NSString *pk=@"asdfasfd";
            [Bonjour publish:serviceTypeBonjour pkType:pkType pk:pk host:host port:port result:^(NSDictionary<NSString *, NSNumber *> *dict){
                NSLog(@"failed to publish:%@",dict);
                
                if(dict){}else{
                    if(searchBonjour){
                        dispatch_async(dispatch_get_main_queue(), ^{

                        [Bonjour startSearch:serviceTypeBonjour result:^(NSDictionary<NSString *, NSNumber *> *dict){
                            NSLog(@"failed to start search:%@",dict);
                        }];
                        });
                    }
                }
            }];
        }
//        if(searchBonjour){
//            [Bonjour startSearch:serviceTypeBonjour result:^(NSDictionary<NSString *, NSNumber *> *dict){
//                NSLog(@"failed to start search:%@",dict);
//            }];
//        }
    }
    [self refreshDir];
    self.msgs.dataSource=self;
    self.msgs.delegate=self;
}
-(void)onPlayInfo:(NSDictionary<NSString*,NSString*> *)dict{
    NSString *state=dict[@"state"];
    if([@"playing" isEqualToString:state]
       ||[@"prepared" isEqualToString:state]){
        long duration=dict[@"duration"].integerValue;
        long current=dict[@"current"].integerValue;
        self->durationPlay=duration;
        //                        CGFloat p=current*100;
        //                        p/=duration;
        if([@"prepared" isEqualToString:state]){
            self->isPlaying=NO;
        }else{
            self->playStart=[NSDate new].timeIntervalSince1970*1000; //seconds into milliseoncs
            //                        self->playStart*=1000; //now in milliseconds
            self->playStart-=current;
            //                        [self.progressPlay setProgress:p];
            //                        NSInteger isPlay=true;
            self->isPlaying=YES;
            [self updateProgressPlay];
        }
    } else if([@"done" isEqualToString:state]){
        self->isPlaying=NO;
        //                        [self.progressPlay setProgress:1];
    }else{
        NSLog(@"unprocessed json:%@",state);
    }
}
-(void)updateProgressPlay{
    long ltsnow=[NSDate new].timeIntervalSince1970*1000; //seconds into milliseoncs
    CGFloat dt=ltsnow-self->playStart;
    //    dt*=100;
    dt/=self->durationPlay;
    //    NSLog(@"progress:%f",dt); //between 0 & 1
    self.progressPlay.progress=dt;
    //    self.progressRecord.progress=dt; //for test
    if(self->isPlaying){
        [self performSelector:@selector(updateProgressPlay) withObject:nil afterDelay:0.2]; //0.2 seconds
    }
}

- (IBAction)doPlay:(id)sender {
    self->fnPlay=self->fnToPlay;
    [av play:self->fnPlay  startPoint:self.autoStart?0:-1];
}

- (IBAction)pausePlay:(id)sender {
    [av pause];
}

- (IBAction)resumePlay:(id)sender {
    [av resume];
}


-(void)onRecordInfo:(NSDictionary<NSString*,NSString*> *)dict{
    NSString *state=dict[@"state"];
    if([@"recording" isEqualToString:state]){
        long duration=dict[@"duration"].integerValue;
        //        long current=dict[@"current"].integerValue;
        self->durationRecord=duration;
        //                        CGFloat p=current*100;
        //                        p/=duration;
        if([@"prepared" isEqualToString:state]){
            self->isRecording=NO;
        }else{
            self->recordStart=[NSDate new].timeIntervalSince1970*1000; //seconds into milliseoncs
            //                        self->playStart*=1000; //now in milliseconds
            //            self->playStart-=current;
            //                        [self.progressPlay setProgress:p];
            //                        NSInteger isPlay=true;
            self->isRecording=YES;
            [self updateProgressRecord];
        }
    } else if([@"stopped" isEqualToString:state]){
        self->isRecording=NO;
        //                        [self.progressPlay setProgress:1];
        [self sendFile:dict[@"fn"]];
    }else{
        NSLog(@"unprocessed json:%@",state);
    }
}
-(void)sendFile:(NSString *)path{
    
    NSMutableDictionary<NSString *,SocketStreams *> *all=[SocketStreams all];
    for(NSString *key in all){
        if([key hasPrefix:@"toLocal"]){
        }else{
            SocketStreams *ss=all[key];
            [ss sendFile:path];//copy the file from pathRecord to
        }
    }
}

-(void)updateProgressRecord{
    long ltsnow=[NSDate new].timeIntervalSince1970*1000; //seconds into milliseoncs
    CGFloat dt=ltsnow-self->recordStart;
    //    dt*=100;
    dt/=self.durationMax4record;
    self.progressRecord.progress=dt;
    if(self->isRecording){
        [self performSelector:@selector(updateProgressRecord) withObject:nil afterDelay:0.2]; //0.2 seconds
    }
}

- (IBAction)startRecord:(id)sender {
    NSDate *dnow=[NSDate new];
    long lts=dnow.timeIntervalSince1970;
    NSString *fn=[NSString stringWithFormat:@"%ld.m4a",lts];
    self->fnRecord=fn;
    [av record:fn duration:self.durationMax4record];
}

- (IBAction)stopRecord:(id)sender {
    [av stopRecord:self->fnRecord];
}
- (IBAction)deleteMSG:(id)sender {
    [av delete:self->fnToPlay];
}
-(BOOL)refreshDir{
    NSLog(@"refresh MSGs requested");
    //-(void)listFilesAudio;
    if(false){
        NSFileManager *fm=[NSFileManager defaultManager];
        NSError *error;
        NSArray<NSString *> *files=[fm contentsOfDirectoryAtPath:[AVsimple singlenton].dir error:&error];
        if(files){
            for(NSString *file in files){
                NSLog(@"file:%@",file);
            }
            self.files=files;
            return YES;
        }else{
            NSLog(@"failed to fetch list:%@",error);
            return NO;
        }
    }else{
        [[AVsimple singlenton] listFilesAudio];
    }
    return YES;
}
- (IBAction)refreshMSGs:(id)sender {
    if([self refreshDir])
        [self.msgs reloadAllComponents];
}




- (IBAction)autoStart:(UISwitch *)sender {
    self.autoStart=sender.on;
}

- (IBAction)seekToPlay:(UISlider *)sender {
    self->startPoint=self->durationPlay*sender.value;
    [av seekToPlay:self->startPoint];
    
}
- (IBAction)adjustPlayVolume:(UISlider *)sender {
    NSLog(@"new volume:%f",sender.value);
    [av changePlayVolume:sender.value];
    //    [av.player setVolume:sender.value fadeDuration:1]; //this requires ios 10.
}




//@protocol UIPickerViewDataSource<NSObject>
//@required
// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView{
    return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component{
    return self.files.count;
}

//@protocol UIPickerViewDelegate<NSObject>
//@optional

// returns width of column and height of row for each component.
//- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component API_UNAVAILABLE(tvos);
//- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component API_UNAVAILABLE(tvos);

// these methods return either a plain NSString, a NSAttributedString, or a view (e.g UILabel) to display the row for the component.
// for the view versions, we cache any hidden and thus unused views and pass them back for reuse.
// If you return back a different object, the old one will be released. the view will be centered in the row rect
- (nullable NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component API_UNAVAILABLE(tvos){
    return self.files[row];
}
//- (nullable NSAttributedString *)pickerView:(UIPickerView *)pickerView attributedTitleForRow:(NSInteger)row forComponent:(NSInteger)component API_AVAILABLE(ios(6.0)) API_UNAVAILABLE(tvos); // attributed title is favored if both methods are implemented
//- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(nullable UIView *)view API_UNAVAILABLE(tvos);

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component{
    self->fnToPlay=self.files[row];
    NSLog(@"select %@",self->fnToPlay);
}

- (IBAction)testInWebView:(id)sender {
    //self.wkWebView load web page
    //just use yjdev9, don't bother.
    
}
- (IBAction)doUpload:(id)sender {
    if(self->fnToPlay){
        NSString *urlBase=@"http://192.168.254.138:8080/Receiver";
        if(self->pathToPlay){
            [av uploadPath:self->pathToPlay fn:self->fnToPlay urlBase:urlBase];
        }else{
            [av upload:self->fnToPlay urlBase:urlBase];
        }
    }else{
        NSLog(@"file not chosen");
    }
    
}

- (IBAction)chooseFile:(id)sender {
    NSArray<NSString *> *dts=@[@"com.pkware.zip-archive"]; //if I use "*", I can not pick any file
    UIDocumentPickerViewController *vc=[[UIDocumentPickerViewController alloc]initWithDocumentTypes:dts inMode:UIDocumentPickerModeOpen];
    if (@available(iOS 11.0, *)) {
        vc.allowsMultipleSelection=NO;
    } else {
        // Fallback on earlier versions
    }
    //    vc.directoryURL=; //its initial location
    vc.delegate=self;
    [self presentViewController:vc animated:YES completion:^{
        
    }];
}


//API_UNAVAILABLE(tvos) @protocol UIDocumentPickerDelegate <NSObject>
//@optional
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray <NSURL *>*)urls API_AVAILABLE(ios(11.0)){
    if(urls.count>0){
        self->fnToPlay=[urls[0] lastPathComponent];
        self->pathToPlay=urls[0].absoluteString;
        NSLog(@"file chosen %lu 0:%@",(unsigned long)urls.count,urls[0]);
        /* NSFileCoordinator is a must? Yes. otherwise, the file can not be opened.
         */
        NSFileCoordinator *fc=[[NSFileCoordinator alloc]init]; //initWithFilePresenter:self
        NSError *error;
        NSURL *url=urls[0];
        [fc coordinateReadingItemAtURL:url
                               options:NSFileCoordinatorReadingWithoutChanges
                                 error:&error
                            byAccessor:^(NSURL *newURL){
            NSLog(@"new url:%@",newURL); //in fact it is same as url
            self->fnToPlay=[av copy:newURL];
            self->pathToPlay=nil; //TODO: remove this variable, it is useless.
        }];
        
    }
}


@end
