import 'package:app/features/chat/group_settings_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner and admin add members directly', () {
    expect(
      resolveGroupMemberAddMode(
        isOwner: true,
        isAdmin: false,
        memberCanInvite: false,
      ),
      GroupMemberAddMode.addDirectly,
    );
    expect(
      resolveGroupMemberAddMode(
        isOwner: false,
        isAdmin: true,
        memberCanInvite: false,
      ),
      GroupMemberAddMode.addDirectly,
    );
  });

  test('ordinary member follows member_can_invite setting', () {
    expect(
      resolveGroupMemberAddMode(
        isOwner: false,
        isAdmin: false,
        memberCanInvite: true,
      ),
      GroupMemberAddMode.invite,
    );
    expect(
      resolveGroupMemberAddMode(
        isOwner: false,
        isAdmin: false,
        memberCanInvite: false,
      ),
      GroupMemberAddMode.hidden,
    );
  });
}
