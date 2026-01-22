//! ReportStore 测试
//!
//! 覆盖举报创建、列表查询等功能。
//!
//! 注意：target_type 定义
//! - 1 = room (群聊举报)
//! - 2 = user (用户举报)

use super::common::{setup_test_db, unique_email, unique_username};
use redcode_im_backend::database::models::CreateUserRequest;
use redcode_im_backend::database::report_store::{
    AdminReportListFilters, ReportAttachmentInsert, ReportInsert, ReportStore,
};
use redcode_im_backend::database::room_store::RoomStore;
use redcode_im_backend::database::user_store::UserStore;
use redcode_im_backend::database::Database;
use sqlx::PgPool;
use uuid::Uuid;

/// 创建测试用户
async fn create_test_user(pool: &PgPool) -> Uuid {
    let store = UserStore::new(Database { pool: pool.clone() });
    let request = CreateUserRequest {
        username: unique_username(),
        email: unique_email(),
        password: "password123".to_string(),
        nickname: Some("Test User".to_string()),
    };
    store.create_user(request).await.unwrap().id
}

/// 创建测试群聊
async fn create_test_room(pool: &PgPool, owner_id: Uuid) -> Uuid {
    let store = RoomStore::new(pool);
    store
        .create_room(owner_id, format!("room_{}", Uuid::new_v4().simple()), None, None)
        .await
        .unwrap()
        .id
}

// ============================================================================
// 创建举报测试
// ============================================================================

#[tokio::test]
async fn test_create_report_user() {
    let test_db = setup_test_db().await;
    let store = ReportStore::new(&test_db.pool);

    let reporter_id = create_test_user(&test_db.pool).await;
    let target_user_id = create_test_user(&test_db.pool).await;

    let insert = ReportInsert {
        id: Uuid::new_v4(),
        reporter_id,
        target_type: 2, // 用户举报 (2=user)
        target_room_id: None,
        target_user_id: Some(target_user_id),
        content: "违规行为描述".to_string(),
    };

    let result = store.create_report(insert, vec![]).await;
    assert!(result.is_ok(), "创建用户举报应成功");
}

#[tokio::test]
async fn test_create_report_room() {
    let test_db = setup_test_db().await;
    let store = ReportStore::new(&test_db.pool);

    let reporter_id = create_test_user(&test_db.pool).await;
    let owner_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    let insert = ReportInsert {
        id: Uuid::new_v4(),
        reporter_id,
        target_type: 1, // 群聊举报 (1=room)
        target_room_id: Some(room_id),
        target_user_id: None,
        content: "群聊违规内容".to_string(),
    };

    let result = store.create_report(insert, vec![]).await;
    assert!(result.is_ok(), "创建群聊举报应成功");
}

#[tokio::test]
async fn test_create_report_with_attachments() {
    let test_db = setup_test_db().await;
    let store = ReportStore::new(&test_db.pool);

    let reporter_id = create_test_user(&test_db.pool).await;
    let target_user_id = create_test_user(&test_db.pool).await;

    let insert = ReportInsert {
        id: Uuid::new_v4(),
        reporter_id,
        target_type: 2, // 用户举报 (2=user)
        target_room_id: None,
        target_user_id: Some(target_user_id),
        content: "附带证据的举报".to_string(),
    };

    let attachments = vec![
        ReportAttachmentInsert {
            object_key: "reports/evidence1.png".to_string(),
            content_type: Some("image/png".to_string()),
            file_size: Some(1024),
        },
        ReportAttachmentInsert {
            object_key: "reports/evidence2.jpg".to_string(),
            content_type: Some("image/jpeg".to_string()),
            file_size: Some(2048),
        },
    ];

    let result = store.create_report(insert, attachments).await;
    assert!(result.is_ok(), "创建带附件的举报应成功");
}

// ============================================================================
// 列表查询测试
// ============================================================================

#[tokio::test]
async fn test_list_admin_reports() {
    let test_db = setup_test_db().await;
    let store = ReportStore::new(&test_db.pool);

    let reporter_id = create_test_user(&test_db.pool).await;
    let target_user_id = create_test_user(&test_db.pool).await;

    // 创建多个举报
    for i in 0..5 {
        let insert = ReportInsert {
            id: Uuid::new_v4(),
            reporter_id,
            target_type: 2, // 用户举报
            target_room_id: None,
            target_user_id: Some(target_user_id),
            content: format!("举报内容 {}", i),
        };
        let _ = store.create_report(insert, vec![]).await.unwrap();
    }

    let filters = AdminReportListFilters {
        reporter_id: None,
        target_type: None,
        target_room_id: None,
        target_user_id: None,
        keyword: None,
        limit: 10,
        offset: 0,
    };

    let result = store.list_admin_reports(&filters).await;
    assert!(result.is_ok(), "列出举报应成功");

    let reports = result.unwrap();
    assert!(reports.len() >= 5, "应至少有 5 条举报");
}

#[tokio::test]
async fn test_list_admin_reports_filter_by_reporter() {
    let test_db = setup_test_db().await;
    let store = ReportStore::new(&test_db.pool);

    let reporter1 = create_test_user(&test_db.pool).await;
    let reporter2 = create_test_user(&test_db.pool).await;
    let target_user = create_test_user(&test_db.pool).await;

    // reporter1 创建 3 条举报
    for _ in 0..3 {
        let insert = ReportInsert {
            id: Uuid::new_v4(),
            reporter_id: reporter1,
            target_type: 2, // 用户举报
            target_room_id: None,
            target_user_id: Some(target_user),
            content: "Reporter 1 的举报".to_string(),
        };
        let _ = store.create_report(insert, vec![]).await.unwrap();
    }

    // reporter2 创建 2 条举报
    for _ in 0..2 {
        let insert = ReportInsert {
            id: Uuid::new_v4(),
            reporter_id: reporter2,
            target_type: 2, // 用户举报
            target_room_id: None,
            target_user_id: Some(target_user),
            content: "Reporter 2 的举报".to_string(),
        };
        let _ = store.create_report(insert, vec![]).await.unwrap();
    }

    // 按 reporter1 过滤
    let filters = AdminReportListFilters {
        reporter_id: Some(reporter1),
        target_type: None,
        target_room_id: None,
        target_user_id: None,
        keyword: None,
        limit: 10,
        offset: 0,
    };

    let result = store.list_admin_reports(&filters).await;
    assert!(result.is_ok());

    let reports = result.unwrap();
    assert_eq!(reports.len(), 3, "应只返回 reporter1 的 3 条举报");
    assert!(
        reports.iter().all(|r| r.reporter_id == reporter1),
        "所有举报应来自 reporter1"
    );
}

#[tokio::test]
async fn test_list_admin_reports_filter_by_target_type() {
    let test_db = setup_test_db().await;
    let store = ReportStore::new(&test_db.pool);

    let reporter_id = create_test_user(&test_db.pool).await;
    let target_user = create_test_user(&test_db.pool).await;
    let owner_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 创建用户举报（type=2）
    let insert = ReportInsert {
        id: Uuid::new_v4(),
        reporter_id,
        target_type: 2,
        target_room_id: None,
        target_user_id: Some(target_user),
        content: "用户举报".to_string(),
    };
    let _ = store.create_report(insert, vec![]).await.unwrap();

    // 创建群聊举报（type=1）
    let insert = ReportInsert {
        id: Uuid::new_v4(),
        reporter_id,
        target_type: 1,
        target_room_id: Some(room_id),
        target_user_id: None,
        content: "群聊举报".to_string(),
    };
    let _ = store.create_report(insert, vec![]).await.unwrap();

    // 只查询用户举报 (type=2)
    let filters = AdminReportListFilters {
        reporter_id: None,
        target_type: Some(2),
        target_room_id: None,
        target_user_id: None,
        keyword: None,
        limit: 10,
        offset: 0,
    };

    let result = store.list_admin_reports(&filters).await;
    assert!(result.is_ok());

    let reports = result.unwrap();
    assert!(
        reports.iter().all(|r| r.target_type == 2),
        "应只返回用户举报"
    );
}

#[tokio::test]
async fn test_list_admin_reports_filter_by_keyword() {
    let test_db = setup_test_db().await;
    let store = ReportStore::new(&test_db.pool);

    let reporter_id = create_test_user(&test_db.pool).await;
    let target_user = create_test_user(&test_db.pool).await;

    // 创建包含特定关键词的举报
    let unique_keyword = format!("UNIQUE_{}", Uuid::new_v4().simple());
    let insert = ReportInsert {
        id: Uuid::new_v4(),
        reporter_id,
        target_type: 2, // 用户举报
        target_room_id: None,
        target_user_id: Some(target_user),
        content: format!("举报内容包含 {}", unique_keyword),
    };
    let _ = store.create_report(insert, vec![]).await.unwrap();

    // 按关键词搜索
    let filters = AdminReportListFilters {
        reporter_id: None,
        target_type: None,
        target_room_id: None,
        target_user_id: None,
        keyword: Some(unique_keyword.clone()),
        limit: 10,
        offset: 0,
    };

    let result = store.list_admin_reports(&filters).await;
    assert!(result.is_ok());

    let reports = result.unwrap();
    assert!(!reports.is_empty(), "应找到包含关键词的举报");
    assert!(
        reports.iter().all(|r| r.content.contains(&unique_keyword)),
        "内容应包含关键词"
    );
}

#[tokio::test]
async fn test_list_admin_reports_pagination() {
    let test_db = setup_test_db().await;
    let store = ReportStore::new(&test_db.pool);

    let reporter_id = create_test_user(&test_db.pool).await;
    let target_user = create_test_user(&test_db.pool).await;

    // 创建 10 条举报
    for i in 0..10 {
        let insert = ReportInsert {
            id: Uuid::new_v4(),
            reporter_id,
            target_type: 2, // 用户举报
            target_room_id: None,
            target_user_id: Some(target_user),
            content: format!("分页测试举报 {}", i),
        };
        let _ = store.create_report(insert, vec![]).await.unwrap();
    }

    // 第一页
    let filters = AdminReportListFilters {
        reporter_id: Some(reporter_id),
        target_type: None,
        target_room_id: None,
        target_user_id: None,
        keyword: None,
        limit: 5,
        offset: 0,
    };

    let page1 = store.list_admin_reports(&filters).await.unwrap();
    assert_eq!(page1.len(), 5, "第一页应有 5 条");

    // 第二页
    let filters = AdminReportListFilters {
        reporter_id: Some(reporter_id),
        target_type: None,
        target_room_id: None,
        target_user_id: None,
        keyword: None,
        limit: 5,
        offset: 5,
    };

    let page2 = store.list_admin_reports(&filters).await.unwrap();
    assert_eq!(page2.len(), 5, "第二页应有 5 条");

    // 确保两页没有重复
    let page1_ids: Vec<_> = page1.iter().map(|r| r.id).collect();
    let page2_ids: Vec<_> = page2.iter().map(|r| r.id).collect();
    assert!(
        page1_ids.iter().all(|id| !page2_ids.contains(id)),
        "两页不应有重复"
    );
}

// ============================================================================
// 计数测试
// ============================================================================

#[tokio::test]
async fn test_count_admin_reports() {
    let test_db = setup_test_db().await;
    let store = ReportStore::new(&test_db.pool);

    let reporter_id = create_test_user(&test_db.pool).await;
    let target_user = create_test_user(&test_db.pool).await;

    // 创建 7 条举报
    for i in 0..7 {
        let insert = ReportInsert {
            id: Uuid::new_v4(),
            reporter_id,
            target_type: 2, // 用户举报
            target_room_id: None,
            target_user_id: Some(target_user),
            content: format!("计数测试举报 {}", i),
        };
        let _ = store.create_report(insert, vec![]).await.unwrap();
    }

    let filters = AdminReportListFilters {
        reporter_id: Some(reporter_id),
        target_type: None,
        target_room_id: None,
        target_user_id: None,
        keyword: None,
        limit: 10,
        offset: 0,
    };

    let result = store.count_admin_reports(&filters).await;
    assert!(result.is_ok(), "计数应成功");
    assert_eq!(result.unwrap(), 7, "应有 7 条举报");
}

#[tokio::test]
async fn test_count_admin_reports_with_filters() {
    let test_db = setup_test_db().await;
    let store = ReportStore::new(&test_db.pool);

    let reporter_id = create_test_user(&test_db.pool).await;
    let target_user1 = create_test_user(&test_db.pool).await;
    let target_user2 = create_test_user(&test_db.pool).await;

    // 针对 target_user1 创建 4 条举报
    for _ in 0..4 {
        let insert = ReportInsert {
            id: Uuid::new_v4(),
            reporter_id,
            target_type: 2, // 用户举报
            target_room_id: None,
            target_user_id: Some(target_user1),
            content: "举报内容".to_string(),
        };
        let _ = store.create_report(insert, vec![]).await.unwrap();
    }

    // 针对 target_user2 创建 2 条举报
    for _ in 0..2 {
        let insert = ReportInsert {
            id: Uuid::new_v4(),
            reporter_id,
            target_type: 2, // 用户举报
            target_room_id: None,
            target_user_id: Some(target_user2),
            content: "举报内容".to_string(),
        };
        let _ = store.create_report(insert, vec![]).await.unwrap();
    }

    // 只计数针对 target_user1 的举报
    let filters = AdminReportListFilters {
        reporter_id: None,
        target_type: None,
        target_room_id: None,
        target_user_id: Some(target_user1),
        keyword: None,
        limit: 10,
        offset: 0,
    };

    let result = store.count_admin_reports(&filters).await;
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), 4, "针对 target_user1 应有 4 条举报");
}

// ============================================================================
// 附件查询测试
// ============================================================================

#[tokio::test]
async fn test_list_attachments_by_report_ids() {
    let test_db = setup_test_db().await;
    let store = ReportStore::new(&test_db.pool);

    let reporter_id = create_test_user(&test_db.pool).await;
    let target_user = create_test_user(&test_db.pool).await;

    let report_id = Uuid::new_v4();
    let insert = ReportInsert {
        id: report_id,
        reporter_id,
        target_type: 2, // 用户举报
        target_room_id: None,
        target_user_id: Some(target_user),
        content: "带附件的举报".to_string(),
    };

    let attachments = vec![
        ReportAttachmentInsert {
            object_key: "reports/file1.png".to_string(),
            content_type: Some("image/png".to_string()),
            file_size: Some(1024),
        },
        ReportAttachmentInsert {
            object_key: "reports/file2.pdf".to_string(),
            content_type: Some("application/pdf".to_string()),
            file_size: Some(2048),
        },
    ];

    let _ = store.create_report(insert, attachments).await.unwrap();

    let result = store.list_attachments_by_report_ids(&[report_id]).await;
    assert!(result.is_ok(), "查询附件应成功");

    let attachments = result.unwrap();
    assert_eq!(attachments.len(), 2, "应有 2 个附件");
    assert!(attachments.iter().all(|a| a.report_id == report_id));
}

#[tokio::test]
async fn test_list_attachments_by_report_ids_empty() {
    let test_db = setup_test_db().await;
    let store = ReportStore::new(&test_db.pool);

    let result = store.list_attachments_by_report_ids(&[]).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_empty(), "空 ID 列表应返回空结果");
}

#[tokio::test]
async fn test_list_attachments_multiple_reports() {
    let test_db = setup_test_db().await;
    let store = ReportStore::new(&test_db.pool);

    let reporter_id = create_test_user(&test_db.pool).await;
    let target_user = create_test_user(&test_db.pool).await;

    let mut report_ids = Vec::new();

    // 创建 3 个带附件的举报
    for i in 0..3 {
        let report_id = Uuid::new_v4();
        report_ids.push(report_id);

        let insert = ReportInsert {
            id: report_id,
            reporter_id,
            target_type: 2, // 用户举报
            target_room_id: None,
            target_user_id: Some(target_user),
            content: format!("举报 {}", i),
        };

        let attachments = vec![ReportAttachmentInsert {
            object_key: format!("reports/file_{}.png", i),
            content_type: Some("image/png".to_string()),
            file_size: Some((i + 1) * 1024),
        }];

        let _ = store.create_report(insert, attachments).await.unwrap();
    }

    let result = store.list_attachments_by_report_ids(&report_ids).await;
    assert!(result.is_ok());

    let attachments = result.unwrap();
    assert_eq!(attachments.len(), 3, "应有 3 个附件");
}
