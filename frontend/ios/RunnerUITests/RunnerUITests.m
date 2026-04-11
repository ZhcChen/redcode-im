@import XCTest;
@import patrol;
@import ObjectiveC.runtime;

@interface XCUIApplicationProcess : NSObject
- (NSString *)bundleID;
- (void)waitForQuiescenceIncludingAnimationsIdle:(BOOL)includingAnimations;
- (void)waitForQuiescenceIncludingAnimationsIdle:(BOOL)includingAnimations isPreEvent:(BOOL)isPreEvent;
@end

@interface XCUIApplicationProcess (RedCodePatrolQuiescence)
@property (nonatomic, strong) NSNumber *redcode_shouldWaitForQuiescence;
@end

static void (*redcode_original_waitForQuiescenceIncludingAnimationsIdle)(id, SEL, BOOL);
static void (*redcode_original_waitForQuiescenceIncludingAnimationsIdlePreEvent)(id, SEL, BOOL, BOOL);

static NSNumber *RedCodePatrolShouldWaitForQuiescence(id self) {
  id result = objc_getAssociatedObject(self, @selector(redcode_shouldWaitForQuiescence));
  if (result == nil) {
    return @(NO);
  }

  return (NSNumber *)result;
}

static void RedCodePatrolSwizzledWaitForQuiescenceIncludingAnimationsIdle(id self, SEL _cmd, BOOL includingAnimations) {
  if (!RedCodePatrolShouldWaitForQuiescence(self).boolValue) {
    NSLog(@"[RedCodePatrol] Skipping quiescence wait for %@", [self bundleID]);
    return;
  }

  redcode_original_waitForQuiescenceIncludingAnimationsIdle(self, _cmd, includingAnimations);
}

static void RedCodePatrolSwizzledWaitForQuiescenceIncludingAnimationsIdlePreEvent(id self, SEL _cmd, BOOL includingAnimations, BOOL isPreEvent) {
  if (!RedCodePatrolShouldWaitForQuiescence(self).boolValue) {
    NSLog(@"[RedCodePatrol] Skipping quiescence wait for %@", [self bundleID]);
    return;
  }

  redcode_original_waitForQuiescenceIncludingAnimationsIdlePreEvent(self, _cmd, includingAnimations, isPreEvent);
}

@implementation XCUIApplicationProcess (RedCodePatrolQuiescence)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-load-method"
#pragma clang diagnostic ignored "-Wcast-function-type-strict"

+ (void)load {
  Method legacyMethod = class_getInstanceMethod(self, @selector(waitForQuiescenceIncludingAnimationsIdle:));
  Method xcode16Method = class_getInstanceMethod(self, @selector(waitForQuiescenceIncludingAnimationsIdle:isPreEvent:));

  if (legacyMethod != nil) {
    IMP swizzledImp = (IMP)RedCodePatrolSwizzledWaitForQuiescenceIncludingAnimationsIdle;
    redcode_original_waitForQuiescenceIncludingAnimationsIdle = (void (*)(id, SEL, BOOL))method_setImplementation(legacyMethod, swizzledImp);
  } else if (xcode16Method != nil) {
    IMP swizzledImp = (IMP)RedCodePatrolSwizzledWaitForQuiescenceIncludingAnimationsIdlePreEvent;
    redcode_original_waitForQuiescenceIncludingAnimationsIdlePreEvent = (void (*)(id, SEL, BOOL, BOOL))method_setImplementation(xcode16Method, swizzledImp);
  } else {
    NSLog(@"[RedCodePatrol] Could not find XCUIApplicationProcess quiescence API");
  }
}

#pragma clang diagnostic pop

- (NSNumber *)redcode_shouldWaitForQuiescence {
  return RedCodePatrolShouldWaitForQuiescence(self);
}

- (void)setRedcode_shouldWaitForQuiescence:(NSNumber *)value {
  objc_setAssociatedObject(self, @selector(redcode_shouldWaitForQuiescence), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

PATROL_INTEGRATION_TEST_IOS_RUNNER(RunnerUITests)
