//
//  TryCatch.h
//  FaceDetect
//
//  Created by B Gay on 8/6/17.
//  Copyright © 2017 Simon Gladman. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TryCatch : NSObject

+ (void)tryRun:(void (^)())tryRun catchRun:(void (^)(NSException *))catchRun finallyRun:(void (^)())finallyRun;
+ (void)throwString:(NSString*)s;
+ (void)throwException:(NSException*)e;

@end
