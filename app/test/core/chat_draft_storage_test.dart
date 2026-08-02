import 'package:app/core/storage/chat_draft_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('drafts are isolated by account and room', () async {
    final storage = ChatDraftStorage();
    await Future.wait([
      storage.save(accountId: 'u1', roomId: 'r1', text: 'draft one'),
      storage.save(accountId: 'u1', roomId: 'r2', text: 'draft two'),
      storage.save(accountId: 'u2', roomId: 'r1', text: 'other account'),
    ]);

    expect(await storage.load(accountId: 'u1', roomId: 'r1'), 'draft one');
    expect(await storage.load(accountId: 'u1', roomId: 'r2'), 'draft two');
    expect(await storage.load(accountId: 'u2', roomId: 'r1'), 'other account');
  });

  test('blank save clears only the selected draft', () async {
    final storage = ChatDraftStorage();
    await storage.save(accountId: 'u1', roomId: 'r1', text: 'draft one');
    await storage.save(accountId: 'u1', roomId: 'r2', text: 'draft two');

    await storage.clear(accountId: 'u1', roomId: 'r1');

    expect(await storage.load(accountId: 'u1', roomId: 'r1'), isNull);
    expect(await storage.load(accountId: 'u1', roomId: 'r2'), 'draft two');
  });

  test('malformed persisted data is ignored', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'chat_text_drafts_v1': '{invalid',
    });

    expect(
      await ChatDraftStorage().load(accountId: 'u1', roomId: 'r1'),
      isNull,
    );
  });
}
