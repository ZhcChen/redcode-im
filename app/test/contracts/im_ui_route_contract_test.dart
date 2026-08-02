import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

enum RouteDelivery { p0, p1, designSourceOnly, notApplicable }

class RouteContract {
  const RouteContract({
    required this.previewPath,
    required this.delivery,
    required this.flutterTarget,
  });

  final String previewPath;
  final RouteDelivery delivery;
  final String flutterTarget;
}

const routeContracts = <String, RouteContract>{
  'auth-login': RouteContract(
    previewPath: '/auth/login',
    delivery: RouteDelivery.p0,
    flutterTarget: 'auth/login',
  ),
  'chats': RouteContract(
    previewPath: '/chats',
    delivery: RouteDelivery.p0,
    flutterTarget: 'home/chats',
  ),
  'chat-detail': RouteContract(
    previewPath: '/chat/c_room_launch',
    delivery: RouteDelivery.p0,
    flutterTarget: 'chat/detail/:chatId',
  ),
  'message-reads': RouteContract(
    previewPath: '/chat/c_room_launch/message/m_1001/reads',
    delivery: RouteDelivery.p0,
    flutterTarget: 'chat/:chatId/message/:messageId/reads',
  ),
  'message-forward': RouteContract(
    previewPath: '/chat/c_room_launch/forward/m_1001',
    delivery: RouteDelivery.p0,
    flutterTarget: 'chat/:chatId/forward/:messageId',
  ),
  'contacts': RouteContract(
    previewPath: '/contacts',
    delivery: RouteDelivery.p0,
    flutterTarget: 'home/contacts',
  ),
  'contact-requests': RouteContract(
    previewPath: '/contacts/requests',
    delivery: RouteDelivery.p0,
    flutterTarget: 'contacts/requests',
  ),
  'contact-add': RouteContract(
    previewPath: '/contacts/add',
    delivery: RouteDelivery.p0,
    flutterTarget: 'contacts/add',
  ),
  'contact-profile': RouteContract(
    previewPath: '/contacts/profile/u_alice',
    delivery: RouteDelivery.p0,
    flutterTarget: 'contacts/profile/:contactId',
  ),
  'contact-report': RouteContract(
    previewPath: '/contacts/profile/u_alice/report',
    delivery: RouteDelivery.p0,
    flutterTarget: 'contacts/profile/:contactId/report',
  ),
  'discover': RouteContract(
    previewPath: '/discover',
    delivery: RouteDelivery.p0,
    flutterTarget: 'home/discover',
  ),
  'moments': RouteContract(
    previewPath: '/discover/moments',
    delivery: RouteDelivery.p1,
    flutterTarget: 'discover/moments',
  ),
  'moment-detail': RouteContract(
    previewPath: '/discover/moments/mom_1002',
    delivery: RouteDelivery.p1,
    flutterTarget: 'discover/moments/:momentId',
  ),
  'scan': RouteContract(
    previewPath: '/discover/scan',
    delivery: RouteDelivery.p1,
    flutterTarget: 'discover/scan',
  ),
  'nearby': RouteContract(
    previewPath: '/discover/nearby',
    delivery: RouteDelivery.p1,
    flutterTarget: 'discover/nearby',
  ),
  'games': RouteContract(
    previewPath: '/discover/games',
    delivery: RouteDelivery.p1,
    flutterTarget: 'discover/games',
  ),
  'groups': RouteContract(
    previewPath: '/groups',
    delivery: RouteDelivery.p0,
    flutterTarget: 'groups',
  ),
  'group-create': RouteContract(
    previewPath: '/groups/create',
    delivery: RouteDelivery.p0,
    flutterTarget: 'groups/create',
  ),
  'group-settings': RouteContract(
    previewPath: '/groups/settings/g_launch',
    delivery: RouteDelivery.p0,
    flutterTarget: 'groups/settings/:groupId',
  ),
  'group-members': RouteContract(
    previewPath: '/groups/g_launch/members',
    delivery: RouteDelivery.p0,
    flutterTarget: 'groups/:groupId/members',
  ),
  'group-admins': RouteContract(
    previewPath: '/groups/g_launch/admins',
    delivery: RouteDelivery.p0,
    flutterTarget: 'groups/:groupId/admins',
  ),
  'group-join-requests': RouteContract(
    previewPath: '/groups/g_launch/join-requests',
    delivery: RouteDelivery.p0,
    flutterTarget: 'groups/:groupId/join-requests',
  ),
  'group-invite': RouteContract(
    previewPath: '/groups/g_launch/invite',
    delivery: RouteDelivery.p0,
    flutterTarget: 'groups/:groupId/invite',
  ),
  'group-invitation': RouteContract(
    previewPath: '/groups/g_launch/invitations/inv_1',
    delivery: RouteDelivery.p0,
    flutterTarget: 'groups/:groupId/invitations/:invitationId',
  ),
  'group-rules': RouteContract(
    previewPath: '/groups/g_launch/rules',
    delivery: RouteDelivery.p0,
    flutterTarget: 'groups/:groupId/rules',
  ),
  'group-mutes': RouteContract(
    previewPath: '/groups/g_launch/mutes',
    delivery: RouteDelivery.p0,
    flutterTarget: 'groups/:groupId/mutes',
  ),
  'group-operation-logs': RouteContract(
    previewPath: '/groups/g_launch/operation-logs',
    delivery: RouteDelivery.p0,
    flutterTarget: 'groups/:groupId/operation-logs',
  ),
  'stickers': RouteContract(
    previewPath: '/stickers',
    delivery: RouteDelivery.p0,
    flutterTarget: 'stickers',
  ),
  'sticker-store': RouteContract(
    previewPath: '/stickers/store',
    delivery: RouteDelivery.p0,
    flutterTarget: 'stickers/store',
  ),
  'sticker-pack': RouteContract(
    previewPath: '/stickers/packs/pack_focus',
    delivery: RouteDelivery.p0,
    flutterTarget: 'stickers/packs/:packId',
  ),
  'search': RouteContract(
    previewPath: '/search',
    delivery: RouteDelivery.p0,
    flutterTarget: 'search/messages',
  ),
  'mine': RouteContract(
    previewPath: '/mine',
    delivery: RouteDelivery.p0,
    flutterTarget: 'home/mine',
  ),
  'mine-profile': RouteContract(
    previewPath: '/mine/profile',
    delivery: RouteDelivery.p0,
    flutterTarget: 'mine/profile',
  ),
  'settings': RouteContract(
    previewPath: '/settings',
    delivery: RouteDelivery.p0,
    flutterTarget: 'mine/settings',
  ),
  'settings-account': RouteContract(
    previewPath: '/settings/account',
    delivery: RouteDelivery.p0,
    flutterTarget: 'mine/settings/account',
  ),
  'settings-chat': RouteContract(
    previewPath: '/settings/chat',
    delivery: RouteDelivery.p0,
    flutterTarget: 'mine/settings/chat',
  ),
  'settings-privacy': RouteContract(
    previewPath: '/settings/privacy',
    delivery: RouteDelivery.p0,
    flutterTarget: 'mine/settings/privacy',
  ),
  'settings-about': RouteContract(
    previewPath: '/settings/about',
    delivery: RouteDelivery.p0,
    flutterTarget: 'mine/settings/about',
  ),
  'settings-profile-edit': RouteContract(
    previewPath: '/settings/profile/edit',
    delivery: RouteDelivery.p0,
    flutterTarget: 'mine/settings/profile/edit',
  ),
  'settings-feedback': RouteContract(
    previewPath: '/settings/feedback',
    delivery: RouteDelivery.p0,
    flutterTarget: 'mine/settings/feedback',
  ),
  'settings-password': RouteContract(
    previewPath: '/settings/password',
    delivery: RouteDelivery.p0,
    flutterTarget: 'mine/settings/password',
  ),
  'settings-deactivate': RouteContract(
    previewPath: '/settings/deactivate',
    delivery: RouteDelivery.p0,
    flutterTarget: 'mine/settings/deactivate',
  ),
  'settings-version': RouteContract(
    previewPath: '/settings/version',
    delivery: RouteDelivery.p0,
    flutterTarget: 'mine/settings/version',
  ),
};

void main() {
  test(
    'all frozen preview routes have one Flutter delivery classification',
    () {
      final source = _previewRouteSource().readAsStringSync();
      final matches = RegExp(
        r"\{ id: '([^']+)', path: '([^']+)' \}",
      ).allMatches(source).toList(growable: false);
      final parsed = <String, String>{
        for (final match in matches) match.group(1)!: match.group(2)!,
      };

      expect(matches, hasLength(43));
      expect(parsed, hasLength(43));
      expect(routeContracts.keys.toSet(), parsed.keys.toSet());
      for (final entry in routeContracts.entries) {
        expect(parsed[entry.key], entry.value.previewPath, reason: entry.key);
        expect(entry.value.flutterTarget, isNotEmpty, reason: entry.key);
      }
    },
  );

  test('P0 and P1 route totals stay explicit', () {
    final totals = <RouteDelivery, int>{
      for (final delivery in RouteDelivery.values) delivery: 0,
    };
    for (final contract in routeContracts.values) {
      totals[contract.delivery] = totals[contract.delivery]! + 1;
    }

    expect(totals[RouteDelivery.p0], 38);
    expect(totals[RouteDelivery.p1], 5);
    expect(totals[RouteDelivery.designSourceOnly], 0);
    expect(totals[RouteDelivery.notApplicable], 0);
  });
}

File _previewRouteSource() {
  final candidates = [
    File('../im-ui-html/tests/routes.ts'),
    File('im-ui-html/tests/routes.ts'),
  ];
  return candidates.firstWhere(
    (file) => file.existsSync(),
    orElse: () => throw StateError(
      'Cannot find im-ui-html/tests/routes.ts from ${Directory.current.path}',
    ),
  );
}
