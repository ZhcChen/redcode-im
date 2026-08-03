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

@interface RedCodeDeviceAcceptanceTests : XCTestCase
@end

@implementation RedCodeDeviceAcceptanceTests

- (void)addScreenshotNamed:(NSString *)name forApplication:(XCUIApplication *)app {
  XCTAttachment *screenshot = [XCTAttachment attachmentWithScreenshot:[app screenshot]];
  screenshot.name = name;
  screenshot.lifetime = XCTAttachmentLifetimeKeepAlways;
  [self addAttachment:screenshot];
}

- (void)dismissKeyboardForApplication:(XCUIApplication *)app {
  XCUIElement *keyboard = app.keyboards.firstMatch;
  NSLog(@"[RedCodeDeviceAcceptance] Keyboard hierarchy:\n%@", keyboard.debugDescription);

  NSArray<NSString *> *returnKeyLabels = @[@"完成", @"前往", @"Go", @"Return", @"Done"];
  BOOL tappedReturnKey = NO;
  for (NSString *label in returnKeyLabels) {
    XCUIElement *returnKey = keyboard.buttons[label];
    if (returnKey.exists && returnKey.hittable) {
      [returnKey tap];
      tappedReturnKey = YES;
      break;
    }
  }

  if (!tappedReturnKey) {
    [app typeText:@"\n"];
  }

  NSPredicate *keyboardDismissed = [NSPredicate predicateWithFormat:@"exists == false"];
  XCTNSPredicateExpectation *expectation = [[XCTNSPredicateExpectation alloc]
      initWithPredicate:keyboardDismissed
                 object:keyboard];
  XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:3.0],
                 XCTWaiterResultCompleted);
}

- (void)testSystemKeyboardLayoutAndBackPriority {
  NSDictionary<NSString *, NSString *> *environment = NSProcessInfo.processInfo.environment;
  NSString *account = environment[@"REDCODE_TEST_ACCOUNT"];
  NSString *password = environment[@"REDCODE_TEST_PASSWORD"];
  NSString *peerAccount = environment[@"REDCODE_TEST_PEER_ACCOUNT"];
  XCTAssertGreaterThan(account.length, 0);
  XCTAssertGreaterThan(password.length, 0);
  XCTAssertGreaterThan(peerAccount.length, 0);

  XCUIApplication *app = [[XCUIApplication alloc] init];
  [app launch];

  XCUIApplication *springboard = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.springboard"];
  XCUIElement *denyNotification = springboard.alerts.buttons[@"不允许"];
  if ([denyNotification waitForExistenceWithTimeout:5.0]) {
    [denyNotification tap];
  }

  [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
  XCTAssertEqual(app.state, XCUIApplicationStateRunningForeground);
  [self addScreenshotNamed:@"login-screen" forApplication:app];

  [[app coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.42)] tap];
  XCTAssertTrue([app.keyboards.firstMatch waitForExistenceWithTimeout:3.0]);
  [self addScreenshotNamed:@"login-keyboard" forApplication:app];
  [app typeText:account];

  [[app coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.54)] tap];
  [app typeText:password];
  [self dismissKeyboardForApplication:app];
  [[app coordinateWithNormalizedOffset:CGVectorMake(0.21, 0.68)] tap];
  [app.buttons[@"登录账号"] tap];

  [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:4.0]];
  [self addScreenshotNamed:@"after-login" forApplication:app];

  XCUIElement *contactsTab = [app.buttons matchingPredicate:
      [NSPredicate predicateWithFormat:@"label CONTAINS %@", @"联系人"]].firstMatch;
  XCTAssertTrue([contactsTab waitForExistenceWithTimeout:5.0]);
  [contactsTab tap];

  XCUIElement *peer = [app.staticTexts matchingPredicate:
      [NSPredicate predicateWithFormat:@"label CONTAINS %@", peerAccount]].firstMatch;
  XCTAssertTrue([peer waitForExistenceWithTimeout:5.0]);
  [peer tap];

  XCUIElement *sendMessage = app.buttons[@"发送消息"];
  XCTAssertTrue([sendMessage waitForExistenceWithTimeout:5.0]);
  [sendMessage tap];
  [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];

  XCUIElement *composer = app.textFields.firstMatch;
  XCTAssertTrue([composer waitForExistenceWithTimeout:5.0]);
  [composer tap];
  XCUIElement *chatKeyboard = app.keyboards.firstMatch;
  XCTAssertTrue([chatKeyboard waitForExistenceWithTimeout:3.0]);
  [composer typeText:@"第一行：验证真实系统软键盘。\n第二行：验证多行输入框不会被键盘遮挡。\n第三行：验证发送按钮保持可见。"];

  XCUIElement *sendButton = app.buttons[@"发送"];
  XCTAssertTrue([sendButton waitForExistenceWithTimeout:3.0]);
  XCTAssertLessThanOrEqual(CGRectGetMaxY(composer.frame), CGRectGetMinY(chatKeyboard.frame));
  XCTAssertLessThanOrEqual(CGRectGetMaxY(sendButton.frame), CGRectGetMinY(chatKeyboard.frame));
  XCTAssertGreaterThanOrEqual(CGRectGetMinX(sendButton.frame), 0.0);
  XCTAssertLessThanOrEqual(CGRectGetMaxX(sendButton.frame), app.frame.size.width);
  [self addScreenshotNamed:@"chat-screen" forApplication:app];

  XCUIElement *backButton = app.buttons[@"返回"];
  XCTAssertTrue([backButton waitForExistenceWithTimeout:3.0]);
  [backButton tap];
  NSPredicate *keyboardDismissed = [NSPredicate predicateWithFormat:@"exists == false"];
  XCTNSPredicateExpectation *dismissExpectation = [[XCTNSPredicateExpectation alloc]
      initWithPredicate:keyboardDismissed
                 object:chatKeyboard];
  XCTAssertEqual([XCTWaiter waitForExpectations:@[dismissExpectation] timeout:3.0],
                 XCTWaiterResultCompleted);
  XCTAssertTrue(composer.exists);
  [self addScreenshotNamed:@"chat-keyboard-dismissed" forApplication:app];

  [backButton tap];
  NSPredicate *chatClosed = [NSPredicate predicateWithFormat:@"exists == false"];
  XCTNSPredicateExpectation *closeExpectation = [[XCTNSPredicateExpectation alloc]
      initWithPredicate:chatClosed
                 object:composer];
  XCTAssertEqual([XCTWaiter waitForExpectations:@[closeExpectation] timeout:3.0],
                 XCTWaiterResultCompleted);
}

@end

PATROL_INTEGRATION_TEST_IOS_RUNNER(RunnerUITests)
