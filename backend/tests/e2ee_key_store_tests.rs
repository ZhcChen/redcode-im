//! E2EE KeyStore 集成测试
//!
//! 运行方式：
//! ```bash
//! # 确保数据库运行中且已执行最新迁移
//! cargo test --test e2ee_key_store_tests
//! ```

mod test_config;

use chrono::{Duration, Utc};
use redcode_im_backend::database::e2ee_key_store::{E2eeKeyStore, OneTimePreKeyInsert, SignedPreKeyInsert};
use redcode_im_backend::database::models::CreateUserRequest;
use redcode_im_backend::database::user_store::UserStore;
use redcode_im_backend::database::Database;
use test_config::{cleanup_test_db, setup_test_db};
use uuid::Uuid;

fn unique_username() -> String {
    format!("testuser_{}", Uuid::new_v4().simple())
}

fn unique_email() -> String {
    format!("test_{}@example.com", Uuid::new_v4().simple())
}

fn bytes(n: usize, seed: u8) -> Vec<u8> {
    vec![seed; n]
}

#[tokio::test]
async fn test_save_and_take_one_time_pre_keys() {
    let test_db = setup_test_db().await;
    let db = Database {
        pool: test_db.pool.clone(),
    };

    // 创建测试用户
    let user_store = UserStore::new(Database {
        pool: test_db.pool.clone(),
    });
    let user = user_store
        .create_user(CreateUserRequest {
            username: unique_username(),
            email: unique_email(),
            password: "password123".to_string(),
            nickname: None,
        })
        .await
        .unwrap();

    let store = E2eeKeyStore::new(db.pool());
    let device_id = "device-a";

    store
        .save_key_bundle(
            user.id,
            device_id,
            bytes(32, 1),
            SignedPreKeyInsert {
                key_id: 10,
                public_key: bytes(32, 2),
                signature: bytes(64, 3),
                expires_at: Utc::now() + Duration::days(7),
            },
            vec![
                OneTimePreKeyInsert {
                    key_id: 101,
                    public_key: bytes(32, 4),
                },
                OneTimePreKeyInsert {
                    key_id: 102,
                    public_key: bytes(32, 5),
                },
            ],
        )
        .await
        .unwrap();

    let remaining = store
        .count_unused_one_time_pre_keys(user.id, device_id)
        .await
        .unwrap();
    assert_eq!(remaining, 2);

    let first = store
        .take_one_time_pre_key(user.id, device_id)
        .await
        .unwrap()
        .expect("应取到一个 one_time_pre_key");
    assert!(first.key_id == 101 || first.key_id == 102);

    let remaining = store
        .count_unused_one_time_pre_keys(user.id, device_id)
        .await
        .unwrap();
    assert_eq!(remaining, 1);

    let second = store
        .take_one_time_pre_key(user.id, device_id)
        .await
        .unwrap()
        .expect("应取到第二个 one_time_pre_key");
    assert!(second.key_id == 101 || second.key_id == 102);
    assert_ne!(first.key_id, second.key_id);

    let remaining = store
        .count_unused_one_time_pre_keys(user.id, device_id)
        .await
        .unwrap();
    assert_eq!(remaining, 0);

    let third = store
        .take_one_time_pre_key(user.id, device_id)
        .await
        .unwrap();
    assert!(third.is_none(), "取尽后应返回 None");

    cleanup_test_db(&test_db).await;
}

#[tokio::test]
async fn test_list_devices_and_signed_pre_key() {
    let test_db = setup_test_db().await;
    let db = Database {
        pool: test_db.pool.clone(),
    };

    let user_store = UserStore::new(Database {
        pool: test_db.pool.clone(),
    });
    let user = user_store
        .create_user(CreateUserRequest {
            username: unique_username(),
            email: unique_email(),
            password: "password123".to_string(),
            nickname: None,
        })
        .await
        .unwrap();

    let store = E2eeKeyStore::new(db.pool());

    // 写入两个设备
    for (device_id, seed) in [("device-a", 10u8), ("device-b", 20u8)] {
        store
            .save_key_bundle(
                user.id,
                device_id,
                bytes(32, seed),
                SignedPreKeyInsert {
                    key_id: seed as i32,
                    public_key: bytes(32, seed + 1),
                    signature: bytes(64, seed + 2),
                    expires_at: Utc::now() + Duration::days(7),
                },
                vec![OneTimePreKeyInsert {
                    key_id: seed as i32 + 1000,
                    public_key: bytes(32, seed + 3),
                }],
            )
            .await
            .unwrap();
    }

    let devices = store.list_device_ids(user.id).await.unwrap();
    assert!(devices.contains(&"device-a".to_string()));
    assert!(devices.contains(&"device-b".to_string()));

    let signed = store
        .get_latest_active_signed_pre_key(user.id, "device-a")
        .await
        .unwrap()
        .expect("device-a 应有 signed_pre_key");
    assert_eq!(signed.key_id, 10);

    cleanup_test_db(&test_db).await;
}

