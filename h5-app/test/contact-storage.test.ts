import { beforeEach, describe, expect, it } from 'vitest';

import { ContactStorage } from '@/storage/contact-storage';
import { MemorySqlAdapter } from '@/storage/memory-sql-adapter';
import type { FriendInfo } from '@/types/friend';

const friend = (id: string, nickname: string): FriendInfo => ({
  id: `friend-${id}`,
  user: {
    id,
    username: `${id}@example.com`,
    nickname,
    email: `${id}@example.com`,
  },
  createdAt: '2026-07-02T00:00:00Z',
  remark: null,
});

describe('ContactStorage', () => {
  let adapter: MemorySqlAdapter;
  let storage: ContactStorage;

  beforeEach(() => {
    adapter = new MemorySqlAdapter();
    storage = new ContactStorage(async () => adapter);
  });

  it('saves and loads friends ordered by display name', async () => {
    await storage.saveFriends([
      friend('u2', 'Charlie'),
      friend('u1', 'Alice'),
    ]);

    const loaded = await storage.loadFriends();

    expect(loaded.map((item) => item.user.nickname)).toEqual(['Alice', 'Charlie']);
  });

  it('ignores corrupted cached friend rows', async () => {
    await storage.saveFriends([friend('u1', 'Alice')]);
    adapter.contactRows.set('bad', {
      friend_user_id: 'bad',
      display_name: 'Bad',
      payload: '{bad-json',
    });

    const loaded = await storage.loadFriends();

    expect(loaded.map((item) => item.user.id)).toEqual(['u1']);
  });

  it('clears cached friends', async () => {
    await storage.saveFriends([friend('u1', 'Alice')]);

    await storage.clear();

    expect(await storage.loadFriends()).toEqual([]);
  });
});
