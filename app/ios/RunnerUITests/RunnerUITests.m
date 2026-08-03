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

- (void)addScreenScreenshotNamed:(NSString *)name {
  XCTAttachment *screenshot = [XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];
  screenshot.name = name;
  screenshot.lifetime = XCTAttachmentLifetimeKeepAlways;
  [self addAttachment:screenshot];
}

- (void)swipeBackForApplication:(XCUIApplication *)app {
  XCUICoordinate *start = [app coordinateWithNormalizedOffset:CGVectorMake(0.01, 0.5)];
  XCUICoordinate *end = [app coordinateWithNormalizedOffset:CGVectorMake(0.8, 0.5)];
  [start pressForDuration:0.1 thenDragToCoordinate:end withVelocity:XCUIGestureVelocityFast thenHoldForDuration:0.0];
}

- (XCUIElement *)firstHittableElementInQuery:(XCUIElementQuery *)query {
  for (XCUIElement *element in query.allElementsBoundByIndex) {
    if (element.hittable) return element;
  }
  return query.firstMatch;
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

- (BOOL)openAppsSettingsInApplication:(XCUIApplication *)settings {
  XCUIElement *chatlySettings = settings.buttons[@"com.chatlyme.app"];
  for (NSUInteger navigationAttempt = 0; navigationAttempt < 3; navigationAttempt++) {
    XCUIElement *appsSettings = nil;
    for (NSUInteger scrollAttempt = 0; scrollAttempt <= 5; scrollAttempt++) {
      for (XCUIElement *button in settings.buttons.allElementsBoundByIndex) {
        if ([button.label isEqualToString:@"App"] && button.hittable) {
          appsSettings = button;
          break;
        }
      }
      if (appsSettings != nil) break;
      [settings swipeUp];
    }
    if (appsSettings == nil) continue;
    [appsSettings tap];
    if ([chatlySettings waitForExistenceWithTimeout:3.0]) {
      return YES;
    }
  }
  return NO;
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

  [self swipeBackForApplication:app];

  XCUIElement *mineTab = [app.buttons matchingPredicate:
      [NSPredicate predicateWithFormat:@"label CONTAINS %@", @"我的"]].firstMatch;
  XCTAssertTrue([mineTab waitForExistenceWithTimeout:5.0]);
  [mineTab tap];
  XCUIElementQuery *settingsEntries = [[app descendantsMatchingType:XCUIElementTypeAny]
      matchingPredicate:[NSPredicate predicateWithFormat:@"label BEGINSWITH %@", @"设置"]];
  XCUIElement *settingsEntry = [self firstHittableElementInQuery:settingsEntries];
  XCTAssertTrue([settingsEntry waitForExistenceWithTimeout:5.0]);
  [settingsEntry tap];
  XCUIElementQuery *aboutEntries = [[app descendantsMatchingType:XCUIElementTypeAny]
      matchingPredicate:[NSPredicate predicateWithFormat:@"label BEGINSWITH %@", @"关于 RedCode IM"]];
  XCUIElement *aboutEntry = [self firstHittableElementInQuery:aboutEntries];
  XCTAssertTrue([aboutEntry waitForExistenceWithTimeout:5.0]);
  [aboutEntry tap];
  XCUIElement *versionCheck = app.staticTexts[@"检查新版本"];
  XCTAssertTrue([versionCheck waitForExistenceWithTimeout:5.0]);

  [self swipeBackForApplication:app];
  XCTAssertTrue([[self firstHittableElementInQuery:aboutEntries] waitForExistenceWithTimeout:5.0]);
  [self swipeBackForApplication:app];
  XCTAssertTrue([[self firstHittableElementInQuery:settingsEntries] waitForExistenceWithTimeout:5.0]);
  XCTAssertTrue(mineTab.exists);
  [self addScreenshotNamed:@"native-back-gesture-complete" forApplication:app];
}

- (void)testPhotoDenialAndSettingsRecovery {
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

  XCUIElement *contactsTab = [app.buttons matchingPredicate:
      [NSPredicate predicateWithFormat:@"label CONTAINS %@", @"联系人"]].firstMatch;
  if (![contactsTab waitForExistenceWithTimeout:2.0]) {
    [[app coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.42)] tap];
    XCTAssertTrue([app.keyboards.firstMatch waitForExistenceWithTimeout:3.0]);
    [app typeText:account];
    [[app coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.54)] tap];
    [app typeText:password];
    [self dismissKeyboardForApplication:app];
    [[app coordinateWithNormalizedOffset:CGVectorMake(0.21, 0.68)] tap];
    [app.buttons[@"登录账号"] tap];
  }
  XCTAssertTrue([contactsTab waitForExistenceWithTimeout:8.0]);
  [contactsTab tap];
  XCUIElement *peer = [app.staticTexts matchingPredicate:
      [NSPredicate predicateWithFormat:@"label CONTAINS %@", peerAccount]].firstMatch;
  XCTAssertTrue([peer waitForExistenceWithTimeout:5.0]);
  [peer tap];
  XCUIElement *sendMessage = app.buttons[@"发送消息"];
  XCTAssertTrue([sendMessage waitForExistenceWithTimeout:5.0]);
  [sendMessage tap];

  XCUIElement *moreButton = app.buttons[@"更多功能"];
  XCTAssertTrue([moreButton waitForExistenceWithTimeout:5.0]);
  [moreButton tap];
  XCUIElement *albumButton = app.buttons[@"相册"];
  XCTAssertTrue([albumButton waitForExistenceWithTimeout:3.0]);
  [albumButton tap];

  XCUIElement *permissionAlert = app.alerts.firstMatch;
  if (![permissionAlert waitForExistenceWithTimeout:3.0]) {
    permissionAlert = springboard.alerts.firstMatch;
  }
  XCTAssertTrue([permissionAlert waitForExistenceWithTimeout:3.0]);
  NSLog(@"[RedCodeDeviceAcceptance] Photos alert hierarchy:\n%@", permissionAlert.debugDescription);
  [self addScreenshotNamed:@"photos-permission-alert" forApplication:springboard];
  XCUIElement *denyPhotos = permissionAlert.buttons[@"不允许"];
  if (!denyPhotos.exists) {
    denyPhotos = permissionAlert.buttons[@"Don’t Allow"];
  }
  if (!denyPhotos.exists) {
    denyPhotos = permissionAlert.buttons[@"Don't Allow"];
  }
  XCTAssertTrue(denyPhotos.exists);
  [denyPhotos tap];

  XCTAssertTrue([app.staticTexts[@"需要相册权限"] waitForExistenceWithTimeout:5.0]);
  XCUIElement *openSettings = app.buttons[@"前往设置"];
  XCTAssertTrue(openSettings.exists);
  [openSettings tap];

  XCUIApplication *settings = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.Preferences"];
  XCTAssertTrue([settings waitForState:XCUIApplicationStateRunningForeground timeout:5.0]);
  NSLog(@"[RedCodeDeviceAcceptance] App settings hierarchy:\n%@", settings.debugDescription);
  [self addScreenshotNamed:@"app-settings" forApplication:settings];

  XCTAssertTrue([self openAppsSettingsInApplication:settings]);

  XCUIElement *chatlySettings = settings.buttons[@"com.chatlyme.app"];
  XCTAssertTrue([chatlySettings waitForExistenceWithTimeout:5.0]);
  [chatlySettings tap];
  [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
  NSLog(@"[RedCodeDeviceAcceptance] Chatly settings hierarchy:\n%@", settings.debugDescription);
  [self addScreenshotNamed:@"chatly-settings" forApplication:settings];

  XCUIElement *photosSettings = settings.buttons[@"PHOTOS"];
  XCTAssertTrue([photosSettings waitForExistenceWithTimeout:3.0]);
  [photosSettings tap];
  [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  NSLog(@"[RedCodeDeviceAcceptance] Photos settings hierarchy:\n%@", settings.debugDescription);
  [self addScreenshotNamed:@"photos-settings" forApplication:settings];

  XCUIElement *fullAccess = settings.buttons[@"2"];
  XCTAssertTrue([fullAccess waitForExistenceWithTimeout:3.0]);
  [fullAccess tap];

  [app activate];
  XCTAssertTrue([moreButton waitForExistenceWithTimeout:5.0]);
  [moreButton tap];
  XCTAssertTrue([albumButton waitForExistenceWithTimeout:3.0]);
  [albumButton tap];

  XCUIElement *cancelPicker = app.buttons[@"取消"];
  XCTAssertTrue([cancelPicker waitForExistenceWithTimeout:5.0]);
  [self addScreenshotNamed:@"photos-picker-after-settings-recovery" forApplication:app];
  [cancelPicker tap];
  XCTAssertTrue(moreButton.exists);
}

- (void)testMicrophoneDenialAndSettingsRecovery {
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

  XCUIElement *contactsTab = [app.buttons matchingPredicate:
      [NSPredicate predicateWithFormat:@"label CONTAINS %@", @"联系人"]].firstMatch;
  if (![contactsTab waitForExistenceWithTimeout:2.0]) {
    [[app coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.42)] tap];
    XCTAssertTrue([app.keyboards.firstMatch waitForExistenceWithTimeout:3.0]);
    [app typeText:account];
    [[app coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.54)] tap];
    [app typeText:password];
    [self dismissKeyboardForApplication:app];
    [[app coordinateWithNormalizedOffset:CGVectorMake(0.21, 0.68)] tap];
    [app.buttons[@"登录账号"] tap];
  }
  XCTAssertTrue([contactsTab waitForExistenceWithTimeout:8.0]);
  [contactsTab tap];
  XCUIElement *peer = [app.staticTexts matchingPredicate:
      [NSPredicate predicateWithFormat:@"label CONTAINS %@", peerAccount]].firstMatch;
  XCTAssertTrue([peer waitForExistenceWithTimeout:5.0]);
  [peer tap];
  XCUIElement *sendMessage = app.buttons[@"发送消息"];
  XCTAssertTrue([sendMessage waitForExistenceWithTimeout:5.0]);
  [sendMessage tap];

  XCUIElement *voiceButton = app.buttons[@"语音"];
  XCTAssertTrue([voiceButton waitForExistenceWithTimeout:5.0]);
  [voiceButton tap];
  XCUIElement *recordButton = app.buttons[@"按住录音"];
  XCTAssertTrue([recordButton waitForExistenceWithTimeout:3.0]);
  [recordButton pressForDuration:1.0];

  XCUIElement *permissionAlert = app.alerts.firstMatch;
  if (![permissionAlert waitForExistenceWithTimeout:3.0]) {
    permissionAlert = springboard.alerts.firstMatch;
  }
  XCTAssertTrue([permissionAlert waitForExistenceWithTimeout:3.0]);
  NSLog(@"[RedCodeDeviceAcceptance] Microphone alert hierarchy:\n%@", permissionAlert.debugDescription);
  [self addScreenshotNamed:@"microphone-permission-alert" forApplication:springboard];
  XCUIElement *denyMicrophone = permissionAlert.buttons[@"不允许"];
  if (!denyMicrophone.exists) {
    denyMicrophone = permissionAlert.buttons[@"Don’t Allow"];
  }
  if (!denyMicrophone.exists) {
    denyMicrophone = permissionAlert.buttons[@"Don't Allow"];
  }
  XCTAssertTrue(denyMicrophone.exists);
  [denyMicrophone tap];

  XCTAssertTrue([app.staticTexts[@"需要麦克风权限"] waitForExistenceWithTimeout:5.0]);
  XCUIElement *openSettings = app.buttons[@"前往设置"];
  XCTAssertTrue(openSettings.exists);
  [openSettings tap];

  XCUIApplication *settings = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.Preferences"];
  XCTAssertTrue([settings waitForState:XCUIApplicationStateRunningForeground timeout:5.0]);
  XCTAssertTrue([self openAppsSettingsInApplication:settings]);

  XCUIElement *chatlySettings = settings.buttons[@"com.chatlyme.app"];
  XCTAssertTrue([chatlySettings waitForExistenceWithTimeout:5.0]);
  [chatlySettings tap];
  [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  NSLog(@"[RedCodeDeviceAcceptance] Chatly microphone settings hierarchy:\n%@", settings.debugDescription);
  [self addScreenshotNamed:@"microphone-settings" forApplication:settings];

  XCUIElement *microphoneSwitch = settings.switches[@"麦克风"];
  XCTAssertTrue([microphoneSwitch waitForExistenceWithTimeout:3.0]);
  XCTAssertEqualObjects(microphoneSwitch.value, @"0");
  [[microphoneSwitch coordinateWithNormalizedOffset:CGVectorMake(0.9, 0.5)] tap];
  NSPredicate *microphoneEnabled = [NSPredicate predicateWithFormat:@"value == '1'"];
  XCTNSPredicateExpectation *microphoneExpectation = [[XCTNSPredicateExpectation alloc]
      initWithPredicate:microphoneEnabled
                 object:microphoneSwitch];
  XCTAssertEqual([XCTWaiter waitForExpectations:@[microphoneExpectation] timeout:3.0],
                 XCTWaiterResultCompleted);

  [app activate];
  if (![recordButton waitForExistenceWithTimeout:3.0]) {
    XCTAssertTrue([contactsTab waitForExistenceWithTimeout:5.0]);
    [contactsTab tap];
    XCTAssertTrue([peer waitForExistenceWithTimeout:5.0]);
    [peer tap];
    XCTAssertTrue([sendMessage waitForExistenceWithTimeout:5.0]);
    [sendMessage tap];
    XCTAssertTrue([voiceButton waitForExistenceWithTimeout:5.0]);
    [voiceButton tap];
    recordButton = app.buttons[@"按住录音"];
  }
  XCTAssertTrue([recordButton waitForExistenceWithTimeout:5.0]);
  [self addScreenshotNamed:@"microphone-ready-after-settings-recovery" forApplication:app];
  [recordButton pressForDuration:2.0];
}

- (void)testSystemFilePickerCanCancel {
  NSDictionary<NSString *, NSString *> *environment = NSProcessInfo.processInfo.environment;
  NSString *account = environment[@"REDCODE_TEST_ACCOUNT"];
  NSString *password = environment[@"REDCODE_TEST_PASSWORD"];
  NSString *peerAccount = environment[@"REDCODE_TEST_PEER_ACCOUNT"];
  XCTAssertGreaterThan(account.length, 0);
  XCTAssertGreaterThan(password.length, 0);
  XCTAssertGreaterThan(peerAccount.length, 0);

  XCUIApplication *app = [[XCUIApplication alloc] init];
  [app launch];

  XCUIElement *contactsTab = [app.buttons matchingPredicate:
      [NSPredicate predicateWithFormat:@"label CONTAINS %@", @"联系人"]].firstMatch;
  if (![contactsTab waitForExistenceWithTimeout:2.0]) {
    [[app coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.42)] tap];
    XCTAssertTrue([app.keyboards.firstMatch waitForExistenceWithTimeout:3.0]);
    [app typeText:account];
    [[app coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.54)] tap];
    [app typeText:password];
    [self dismissKeyboardForApplication:app];
    [[app coordinateWithNormalizedOffset:CGVectorMake(0.21, 0.68)] tap];
    [app.buttons[@"登录账号"] tap];
  }
  XCTAssertTrue([contactsTab waitForExistenceWithTimeout:8.0]);
  [contactsTab tap];
  XCUIElement *peer = [app.staticTexts matchingPredicate:
      [NSPredicate predicateWithFormat:@"label CONTAINS %@", peerAccount]].firstMatch;
  XCTAssertTrue([peer waitForExistenceWithTimeout:5.0]);
  [peer tap];
  XCUIElement *sendMessage = app.buttons[@"发送消息"];
  XCTAssertTrue([sendMessage waitForExistenceWithTimeout:5.0]);
  [sendMessage tap];

  XCUIElement *composer = app.textFields.firstMatch;
  XCTAssertTrue([composer waitForExistenceWithTimeout:5.0]);
  XCUIElement *moreButton = app.buttons[@"更多功能"];
  XCTAssertTrue(moreButton.exists);
  [moreButton tap];
  XCUIElement *fileButton = app.buttons[@"文件"];
  XCTAssertTrue([fileButton waitForExistenceWithTimeout:3.0]);
  [fileButton tap];
  [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
  [self addScreenScreenshotNamed:@"system-file-picker-screen"];

  XCUIElement *pickerTitle = app.staticTexts[@"最近项目"];
  XCTAssertTrue([pickerTitle waitForExistenceWithTimeout:5.0]);
  XCUIElement *closePicker = [[[app descendantsMatchingType:XCUIElementTypeAny]
      matchingPredicate:[NSPredicate predicateWithFormat:@"label == %@", @"Cancel"]] firstMatch];
  XCTAssertTrue([closePicker waitForExistenceWithTimeout:5.0]);
  [self addScreenshotNamed:@"system-file-picker" forApplication:app];
  [closePicker tap];

  XCTAssertTrue([app waitForState:XCUIApplicationStateRunningForeground timeout:5.0]);
  XCTAssertTrue([composer waitForExistenceWithTimeout:5.0]);
  XCTAssertTrue(moreButton.exists);
  XCTAssertFalse(app.staticTexts[@"访问文件失败"].exists);
  XCTAssertFalse(app.staticTexts[@"处理文件失败"].exists);
  [self addScreenshotNamed:@"chat-after-file-picker-cancel" forApplication:app];
}

@end

PATROL_INTEGRATION_TEST_IOS_RUNNER(RunnerUITests)
