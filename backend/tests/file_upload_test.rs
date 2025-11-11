#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[tokio::test]
    async fn test_avatar_file_validation() {
        // 测试头像文件验证
        let app = create_test_app().await;

        // 测试不支持的文件类型
        let response = app
            .post("/users/me/avatar/direct-upload")
            .json(&json!({
                "content_type": "application/pdf",
                "file_size": 1024
            }))
            .await;

        assert_eq!(response.status(), 200);
        let body: serde_json::Value = response.json().await;
        assert_eq!(body["success"], false);
        assert!(body["message"]
            .as_str()
            .unwrap()
            .contains("不支持的文件类型"));

        // 测试文件大小超出限制
        let response = app
            .post("/users/me/avatar/direct-upload")
            .json(&json!({
                "content_type": "image/jpeg",
                "file_size": 10 * 1024 * 1024 // 10MB，超过5MB限制
            }))
            .await;

        assert_eq!(response.status(), 200);
        let body: serde_json::Value = response.json().await;
        assert_eq!(body["success"], false);
        assert!(body["message"]
            .as_str()
            .unwrap()
            .contains("文件大小超出限制"));

        // 测试有效的头像文件
        let response = app
            .post("/users/me/avatar/direct-upload")
            .json(&json!({
                "content_type": "image/jpeg",
                "file_size": 1024
            }))
            .await;

        assert_eq!(response.status(), 200);
        let body: serde_json::Value = response.json().await;
        assert_eq!(body["success"], true);
        assert!(body["key"].is_string());
        assert!(body["signature"].is_object());
    }

    #[tokio::test]
    async fn test_message_attachment_validation() {
        // 测试消息附件验证
        let app = create_test_app().await;

        // 模拟用户登录
        let user_id = uuid::Uuid::new_v4().to_string();
        let claims = crate::models::Claims {
            sub: user_id.clone(),
            exp: (chrono::Utc::now() + chrono::Duration::hours(1)).timestamp() as usize,
            iat: chrono::Utc::now().timestamp() as usize,
        };

        let token = generate_test_token(&claims);

        // 测试语音文件上传
        let room_id = uuid::Uuid::new_v4();
        let response = app
            .post(&format!(
                "/rooms/{}/messages/attachments/signature",
                room_id
            ))
            .header("Authorization", format!("Bearer {}", token))
            .json(&json!({
                "part_type": 4, // AUDIO_CONTENT_TYPE
                "filename": "voice_test.webm",
                "content_type": "audio/webm",
                "file_size": 1024 * 1024 // 1MB
            }))
            .await;

        assert_eq!(response.status(), 200);
        let body: serde_json::Value = response.json().await;
        assert_eq!(body["success"], true);
        assert!(body["key"].is_string());
        assert!(body["signature"].is_object());

        // 测试音频文件大小超出限制
        let response = app
            .post(&format!(
                "/rooms/{}/messages/attachments/signature",
                room_id
            ))
            .header("Authorization", format!("Bearer {}", token))
            .json(&json!({
                "part_type": 4,
                "filename": "voice_too_large.webm",
                "content_type": "audio/webm",
                "file_size": 25 * 1024 * 1024 // 25MB，超过20MB限制
            }))
            .await;

        assert_eq!(response.status(), 400);
        let body: serde_json::Value = response.json().await;
        assert!(body["message"]
            .as_str()
            .unwrap()
            .contains("文件大小超出限制"));
    }

    // 测试辅助函数
    async fn create_test_app() -> axum::Router<crate::AppState> {
        // 这里需要根据实际的应用结构创建测试应用
        // 由于这是测试代码，需要设置测试数据库和存储
        todo!("实现测试应用创建逻辑")
    }

    fn generate_test_token(claims: &crate::models::Claims) -> String {
        // 这里需要根据实际的JWT生成逻辑创建测试token
        todo!("实现测试token生成逻辑")
    }
}
