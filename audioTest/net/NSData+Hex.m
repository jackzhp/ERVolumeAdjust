//
//  NSData+Hex.m
//  audioTest
//
//  Created by yogi on 6/19/20.
//  Copyright © 2020 zed. All rights reserved.
//

#import "NSData+Hex.h"

@implementation NSData (Hex)

- (NSString *)toHex{
    NSUInteger          dataLength  = [self length];
    NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    const uint8_t *p=self.bytes;
    for (int i = 0; i < dataLength; ++i)
        [hexString appendString:[NSString stringWithFormat:@"%02X", p[i]]];
    return [NSString stringWithString:hexString];
}
+(int)a2i:(unichar)c{
    int iret;
    if(c>='0' && c<='9') iret=c-'0';
    else {
        if(c>='A' && c<='F') iret=c-'A';
        else if(c>='a' && c<='f' ) iret=c-'a';
        else @throw [[NSException alloc]initWithName:@"HexToInteger" reason:[NSString stringWithFormat:@"not hex:%02X:%c",c,c] userInfo:nil];
        iret+=10;
    }
    return iret;
}
+(NSData *)fromHex:(NSString *)hex{
    NSUInteger len=hex.length>>1;
    BOOL even=YES;
    if((len<<1)!=hex.length){
        len++;
        even=NO;
    }
    uint8_t p[len];
    int i=0,j=0;
    if(even){
    }else{
        unichar c=[hex characterAtIndex:j++];
        p[i++]=[NSData a2i:c];
    }
    for(;i<len;i++){
        int h=[NSData a2i:[hex characterAtIndex:j++]];
        int l=[NSData a2i:[hex characterAtIndex:j++]];
        p[i]=(h<<4)+l;
    }
    return [[NSData alloc]initWithBytes:p length:len];
}

@end
