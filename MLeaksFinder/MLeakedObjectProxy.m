/**
 * Tencent is pleased to support the open source community by making MLeaksFinder available.
 *
 * Copyright (C) 2017 THL A29 Limited, a Tencent company. All rights reserved.
 *
 * Licensed under the BSD 3-Clause License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 *
 * https://opensource.org/licenses/BSD-3-Clause
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

#import "MLeakedObjectProxy.h"
#import "MLeaksFinder.h"
#import "NSObject+MemoryLeak.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

#if __has_include(<MLeaksFinder/MLeaksFinder-Swift.h>)
#import <MLeaksFinder/MLeaksFinder-Swift.h>
#elif __has_include("MLeaksFinder-Swift.h")
#import "MLeaksFinder-Swift.h"
#endif

#if _INTERNAL_MLF_RC_ENABLED
#import <FBRetainCycleDetector/FBRetainCycleDetector.h>
#endif

static MLeaksFinderLogger *logger = nil;

@interface MLeakedObjectProxy ()
@property (nonatomic, weak) id object;
@property (nonatomic, strong) NSNumber *objectPtr;
@property (nonatomic, strong) NSArray *viewStack;
@end

@implementation MLeakedObjectProxy

+ (void)load {
    leakedObjectPtrs = [[NSMutableSet alloc] init];
    logger = [MLeaksFinderLogger new];
}

+ (BOOL)isAnyObjectLeakedAtPtrs:(NSSet *)ptrs {
    NSAssert([NSThread isMainThread], @"Must be in main thread.");
    
    if (!ptrs.count) {
        return NO;
    }
    if ([leakedObjectPtrs intersectsSet:ptrs]) {
        return YES;
    } else {
        return NO;
    }
}

+ (void)addLeakedObject:(id)object {
    NSAssert([NSThread isMainThread], @"Must be in main thread.");
    
    MLeakedObjectProxy *proxy = [[MLeakedObjectProxy alloc] init];
    proxy.object = object;
    proxy.objectPtr = @((uintptr_t)object);
    proxy.viewStack = [object viewStack];
    static const void *const kLeakedObjectProxyKey = &kLeakedObjectProxyKey;
    objc_setAssociatedObject(object, kLeakedObjectProxyKey, proxy, OBJC_ASSOCIATION_RETAIN);
    
    [leakedObjectPtrs addObject:proxy.objectPtr];
#if _INTERNAL_MLF_RC_ENABLED
    [self logWithFBRetainCycleDetector];
#else
    [logger log:@"⚠️ Some objects are still alive. Double check if it's expected" :[NSString stringWithFormat:@"%@", proxy.viewStack]];
#endif
}

- (void)logWithFBRetainCycleDetector {
#if _INTERNAL_MLF_RC_ENABLED
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        FBRetainCycleDetector *detector = [FBRetainCycleDetector new];
        [detector addCandidate:self.object];
        NSSet *retainCycles = [detector findRetainCyclesWithMaxCycleLength:20];

        BOOL hasFound = NO;
        for (NSArray *retainCycle in retainCycles) {
            NSInteger index = 0;
            for (FBObjectiveCGraphElement *element in retainCycle) {
                if (element.object == object) {
                    NSArray *shiftedRetainCycle = [self shiftArray:retainCycle toIndex:index];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [logger log: @"‼️ Retain cycle detected" :[NSString stringWithFormat:@"%@", shiftedRetainCycle]];
                    });
                    hasFound = YES;
                    break;
                }

                ++index;
            }
            if (hasFound) {
                break;
            }
        }
        if (!hasFound) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [logger log: @"Retain cycle" :@"Fail to find a retain cycle"];
            });
        }
    });
#endif
}

- (NSArray *)shiftArray:(NSArray *)array toIndex:(NSInteger)index {
    if (index == 0) {
        return array;
    }
    
    NSRange range = NSMakeRange(index, array.count - index);
    NSMutableArray *result = [[array subarrayWithRange:range] mutableCopy];
    [result addObjectsFromArray:[array subarrayWithRange:NSMakeRange(0, index)]];
    return result;
}

@end
