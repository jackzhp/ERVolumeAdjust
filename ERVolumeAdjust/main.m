//
//  main.m
//  ERVolumeAdjust
//
//  Created by Eric Robinson on 5/24/13.
//  Copyright (c) 2013 Eric Robinson. All rights reserved.
//

//#import <Cocoa/Cocoa.h>
#import <UIKit/UIKit.h>
#import "AppDelegate.h"


int main(int argc, char *argv[])
{
    
//    return NSApplicationMain(argc, (const char **)argv); //mac 10
    
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);

}
