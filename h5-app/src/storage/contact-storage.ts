import type { FriendInfo } from '@/types/friend';

import { getLocalDatabase } from './local-database';
import type { SqlAdapter } from './sql-adapter';

interface ContactRow {
  friend_user_id: string;
  display_name: string;
  payload: string;
}

export class ContactStorage {
  constructor(private readonly adapterFactory: () => Promise<SqlAdapter> = getLocalDatabase) {}

  async loadFriends(): Promise<FriendInfo[]> {
    const db = await this.ready();
    const rows = await db.query<ContactRow>(
      'SELECT friend_user_id, display_name, payload FROM contacts ORDER BY display_name ASC',
    );
    return rows.flatMap((row) => parseFriend(row.payload));
  }

  async saveFriends(friends: FriendInfo[]): Promise<void> {
    const db = await this.ready();
    const sorted = friends.slice().sort(compareFriend);
    await db.transaction(async (tx) => {
      await tx.execute('DELETE FROM contacts');
      for (const friend of sorted) {
        if (!friend.user.id) continue;
        await tx.execute(
          `INSERT OR REPLACE INTO contacts
           (friend_user_id, display_name, payload)
           VALUES (?, ?, ?)`,
          [friend.user.id, displayName(friend), JSON.stringify(friend)],
        );
      }
    });
  }

  async clear(): Promise<void> {
    const db = await this.ready();
    await db.execute('DELETE FROM contacts');
  }

  private async ready() {
    const db = await this.adapterFactory();
    await db.execute(`
      CREATE TABLE IF NOT EXISTS contacts (
        friend_user_id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    `);
    await db.execute('CREATE INDEX IF NOT EXISTS idx_contacts_display_name ON contacts (display_name)');
    return db;
  }
}

const parseFriend = (payload: string): FriendInfo[] => {
  try {
    const parsed = JSON.parse(payload) as Partial<FriendInfo>;
    if (!parsed.user?.id) return [];
    return [parsed as FriendInfo];
  } catch {
    return [];
  }
};

export const displayName = (friend: FriendInfo) =>
  friend.remark?.trim() || friend.user.nickname || friend.user.email || friend.user.username || 'RedCode 用户';

export const compareFriend = (a: FriendInfo, b: FriendInfo) =>
  displayName(a).localeCompare(displayName(b), 'zh-Hans-CN');
