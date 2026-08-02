import 'package:app/core/services/feedback_service.dart';
import 'package:app/core/services/version_service.dart';
import 'package:app/core/update/hot_update_models.dart';
import 'package:app/features/settings/feedback_page.dart';
import 'package:app/features/settings/version_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingFeedbackService extends FeedbackService {
  @override
  Future<void> submitFeedback({required String content, String? contact}) {
    throw FeedbackServiceException('服务暂不可用');
  }
}

AppVersionInfo _version({required bool mandatory}) => AppVersionInfo(
  id: 'v-1',
  platform: 'android',
  version: '2.0.1',
  buildNumber: 2,
  channel: 'stable',
  downloadKey: 'versions/app.apk',
  mandatory: mandatory,
  isActive: true,
);

void main() {
  test('version status covers native and hot update states', () {
    expect(
      resolveVersionStatus(checking: false).kind,
      VersionStatusKind.latest,
    );
    expect(
      resolveVersionStatus(
        checking: false,
        result: VersionCheckResult(
          hasUpdate: true,
          currentVersion: '2.0.0',
          latest: _version(mandatory: false),
        ),
      ).kind,
      VersionStatusKind.optional,
    );
    expect(
      resolveVersionStatus(
        checking: false,
        result: VersionCheckResult(
          hasUpdate: true,
          currentVersion: '2.0.0',
          latest: _version(mandatory: true),
        ),
      ).kind,
      VersionStatusKind.forced,
    );
    expect(
      resolveVersionStatus(checking: false, error: Exception('offline')).kind,
      VersionStatusKind.error,
    );
    expect(
      resolveVersionStatus(
        checking: false,
        hotStage: HotUpdateStage.available,
      ).kind,
      VersionStatusKind.hotAvailable,
    );
    expect(
      resolveVersionStatus(
        checking: false,
        hotStage: HotUpdateStage.applied,
      ).kind,
      VersionStatusKind.hotApplied,
    );
  });

  testWidgets('feedback failure keeps the current form values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackPage(feedbackService: _FailingFeedbackService()),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('feedback-content')),
      '这是一条足够长的反馈内容，用于复现网络失败',
    );
    await tester.enterText(
      find.byKey(const Key('feedback-contact')),
      'alice@example.com',
    );
    await tester.ensureVisible(find.byKey(const Key('feedback-submit')));
    await tester.tap(find.byKey(const Key('feedback-submit')));
    await tester.pump();

    expect(find.text('服务暂不可用'), findsOneWidget);
    expect(find.text('这是一条足够长的反馈内容，用于复现网络失败'), findsOneWidget);
    expect(find.text('alice@example.com'), findsOneWidget);
    expect(find.byType(FeedbackPage), findsOneWidget);
  });
}
