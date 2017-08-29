//
//  TryCatch.m
//  FaceDetect
//
//  Created by B Gay on 8/6/17.
//  Copyright © 2017 Simon Gladman. All rights reserved.
//

#import "TryCatch.h"

@implementation TryCatch

/**
 Provides try catch functionality for swift by wrapping around Objective-C
 */
+(void)tryRun:(void (^)())tryRun catchRun:(void (^)(NSException *))catchRun finallyRun:(void (^)())finallyRun {
    @try {
        tryRun ? tryRun() : nil;
    }
    @catch (NSException *exception) {
        catchRun ? catchRun(exception) : nil;
    }
    @finally {
        finallyRun ? finallyRun() : nil;
    }
}

+ (void)throwString:(NSString*)s
{
    @throw [NSException exceptionWithName:s reason:s userInfo:nil];
}

+ (void)throwException:(NSException*)e
{
    @throw e;
}

@end
