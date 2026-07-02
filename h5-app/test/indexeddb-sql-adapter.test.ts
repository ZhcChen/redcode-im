import { beforeEach, describe, expect, it, vi } from 'vitest';
import { IDBFactory } from 'fake-indexeddb';

import { IndexedDbSqlAdapter } from '@/storage/indexeddb-sql-adapter';

describe('IndexedDbSqlAdapter', () => {
  beforeEach(async () => {
    vi.stubGlobal('indexedDB', new IDBFactory());
    await deleteDatabase('redcode-h5-cache-test');
  });

  it('persists contact/message/cache rows across adapter instances', async () => {
    const first = await IndexedDbSqlAdapter.create('redcode-h5-cache-test');
    await first.execute(
      `INSERT OR REPLACE INTO contacts
       (friend_user_id, display_name, payload)
       VALUES (?, ?, ?)`,
      ['u1', 'Alice', '{"user":{"id":"u1"}}'],
    );
    await first.execute(
      'INSERT OR REPLACE INTO messages (id, room_id, timestamp, payload) VALUES (?, ?, ?, ?)',
      ['m1', 'r1', 1, '{"id":"m1","roomId":"r1","timestamp":1}'],
    );
    await first.close();

    const second = await IndexedDbSqlAdapter.create('redcode-h5-cache-test');

    expect(await second.query('SELECT friend_user_id, display_name, payload FROM contacts')).toEqual([
      {
        friend_user_id: 'u1',
        display_name: 'Alice',
        payload: '{"user":{"id":"u1"}}',
      },
    ]);
    expect(await second.query('SELECT id, room_id, timestamp, payload FROM messages WHERE room_id = ?', ['r1']))
      .toEqual([
        {
          id: 'm1',
          room_id: 'r1',
          timestamp: 1,
          payload: '{"id":"m1","roomId":"r1","timestamp":1}',
        },
      ]);
    await second.close();
  });

  it('rolls back in-memory state when a transaction fails', async () => {
    const adapter = await IndexedDbSqlAdapter.create('redcode-h5-cache-test');

    await expect(adapter.transaction(async () => {
      await adapter.execute(
        `INSERT OR REPLACE INTO contacts
         (friend_user_id, display_name, payload)
         VALUES (?, ?, ?)`,
        ['u1', 'Alice', '{"user":{"id":"u1"}}'],
      );
      throw new Error('boom');
    })).rejects.toThrow('boom');

    expect(await adapter.query('SELECT friend_user_id, display_name, payload FROM contacts')).toEqual([]);
    await adapter.close();
  });

  it('does not persist failed transaction changes across adapter instances', async () => {
    const first = await IndexedDbSqlAdapter.create('redcode-h5-cache-test');

    await expect(first.transaction(async () => {
      await first.execute(
        `INSERT OR REPLACE INTO contacts
         (friend_user_id, display_name, payload)
         VALUES (?, ?, ?)`,
        ['u1', 'Alice', '{"user":{"id":"u1"}}'],
      );
      throw new Error('boom');
    })).rejects.toThrow('boom');
    await first.close();

    const second = await IndexedDbSqlAdapter.create('redcode-h5-cache-test');

    expect(await second.query('SELECT friend_user_id, display_name, payload FROM contacts')).toEqual([]);
    await second.close();
  });
});

const deleteDatabase = async (name: string) => {
  await new Promise<void>((resolve) => {
    const request = indexedDB.deleteDatabase(name);
    request.onsuccess = () => resolve();
    request.onerror = () => resolve();
    request.onblocked = () => resolve();
  });
  vi.clearAllMocks();
};
