//
//  ViewController.h
//  audioTest
//
//  Created by yogi on 5/23/20.
//  Copyright © 2020 zed. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WKWebView.h>

@interface ViewController : UIViewController<UIPickerViewDataSource,UIPickerViewDelegate>

@property (weak, nonatomic) IBOutlet UIPickerView *msgs;
@property (weak, nonatomic) IBOutlet UIProgressView *progressPlay;
@property (weak, nonatomic) IBOutlet UIProgressView *progressRecord;
@property (weak, nonatomic) IBOutlet UISlider *playVolume;
//@property (weak, nonatomic) IBOutlet WKWebView *wkWebView;
@property (weak, nonatomic) IBOutlet UISwitch *vAutoStart;


@property BOOL autoStart;
//@property long durationPlay; //in milliseconds
//@property CGFloat startPoint;
//@property (strong,nonatomic) NSString *fnPlay;
//@property (strong,nonatomic) NSString *fnToPlay;

@property long durationMax4record; //in milliseconds
//@property long durationRecord; //this might be different from durationMax4record
//@property (strong,nonatomic) NSString *fnRecord;


@property (strong, nonatomic) NSArray<NSString *> *files;

@end


