//
//  NSData+Hex.h
//  audioTest
//
//  Created by yogi on 6/19/20.
//  Copyright © 2020 zed. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData (Hex)

- (NSString *)toHex;
+(NSData *)fromHex:(NSString *)hex;


@end

NS_ASSUME_NONNULL_END
