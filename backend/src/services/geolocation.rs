use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Row};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, error, info, warn};

use crate::error::AppError;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IpInfoResponse {
    pub ip: String,
    pub hostname: Option<String>,
    pub city: Option<String>,
    pub region: Option<String>,
    pub country: Option<String>,
    pub loc: Option<String>, // "latitude,longitude"
    pub org: Option<String>,
    pub postal: Option<String>,
    pub timezone: Option<String>,
}

#[derive(Debug, Clone)]
pub struct IpInfoToken {
    pub id: uuid::Uuid,
    pub name: String,
    pub token: String,
    pub monthly_limit: i32,
    pub used_count: i32,
    pub reset_date: chrono::NaiveDate,
    pub status: String,
    pub last_used_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserGeolocation {
    pub user_id: uuid::Uuid,
    pub ip_address: String,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    pub country: Option<String>,
    pub region: Option<String>,
    pub city: Option<String>,
    pub isp: Option<String>,
    pub timezone: Option<String>,
    pub zip_code: Option<String>,
    pub geolocation_source: String,
    pub updated_at: DateTime<Utc>,
}

/// 用于地图显示的用户地理位置汇总数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserLocationMapData {
    pub latitude: f64,
    pub longitude: f64,
    pub country: Option<String>,
    pub region: Option<String>,
    pub city: Option<String>,
    pub user_count: i64,
    pub users: Vec<UserLocationPoint>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserLocationPoint {
    pub user_id: uuid::Uuid,
    pub username: String,
    pub nickname: Option<String>,
}

#[derive(Clone)]
pub struct GeolocationService {
    pool: PgPool,
    http_client: reqwest::Client,
    token_cache: Arc<RwLock<Vec<IpInfoToken>>>,
    #[allow(dead_code)]
    cache_ttl: std::time::Duration,
}

impl GeolocationService {
    pub fn new(pool: PgPool) -> Self {
        Self {
            pool,
            http_client: reqwest::Client::builder()
                .timeout(std::time::Duration::from_secs(10))
                .build()
                .unwrap_or_default(),
            token_cache: Arc::new(RwLock::new(Vec::new())),
            cache_ttl: std::time::Duration::from_secs(300), // 5分钟缓存token
        }
    }

    /// 获取可用的token
    pub async fn get_available_token(&self) -> Result<Option<IpInfoToken>, AppError> {
        // 先检查缓存
        {
            let cache = self.token_cache.read().await;
            if let Some(token) = cache.iter().find(|t| t.status == "active") {
                return Ok(Some(token.clone()));
            }
        }

        // 从数据库获取
        let tokens = sqlx::query(
            r#"
            SELECT id, name, token, monthly_limit, used_count, reset_date, status, last_used_at
            FROM ipinfo_tokens
            WHERE status = 'active'
            ORDER BY last_used_at ASC NULLS FIRST
            LIMIT 1
            "#,
        )
        .fetch_optional(&self.pool)
        .await?;

        if let Some(row) = tokens {
            let token = IpInfoToken {
                id: row.try_get("id")?,
                name: row.try_get("name")?,
                token: row.try_get("token")?,
                monthly_limit: row.try_get("monthly_limit")?,
                used_count: row.try_get("used_count")?,
                reset_date: row.try_get("reset_date")?,
                status: row.try_get("status")?,
                last_used_at: row.try_get("last_used_at")?,
            };

            // 更新缓存
            {
                let mut cache = self.token_cache.write().await;
                cache.clear();
                cache.push(token.clone());
            }

            Ok(Some(token))
        } else {
            warn!("没有可用的ipinfo.io token");
            Ok(None)
        }
    }

    /// 更新token使用统计
    pub async fn update_token_usage(&self, token_id: &uuid::Uuid, ip_address: &str, success: bool) -> Result<(), AppError> {
        // 更新token使用统计
        sqlx::query(
            r#"
            UPDATE ipinfo_tokens
            SET used_count = used_count + 1,
                last_used_at = NOW(),
                status = CASE WHEN used_count + 1 >= monthly_limit THEN 'exhausted' ELSE 'active' END,
                updated_at = NOW()
            WHERE id = $1
            "#,
        )
        .bind(token_id)
        .execute(&self.pool)
        .await?;

        // 清除缓存，强制重新加载
        {
            let mut cache = self.token_cache.write().await;
            cache.clear();
        }

        // 记录使用日志
        sqlx::query(
            r#"
            INSERT INTO ipinfo_token_usage_logs (token_id, ip_address, success)
            VALUES ($1, $2::inet, $3)
            "#,
        )
        .bind(token_id)
        .bind(ip_address)
        .bind(success)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    /// 查询IP地理位置
    pub async fn query_ip_geolocation(&self, ip: &str) -> Result<Option<UserGeolocation>, AppError> {
        let token = match self.get_available_token().await? {
            Some(token) => token,
            None => {
                warn!("没有可用的token用于查询IP: {}", ip);
                return Ok(None);
            }
        };

        let url = format!("https://ipinfo.io/{}/json?token={}", ip, token.token);

        debug!("查询地理位置: {}", url);

        let response = self.http_client.get(&url).send().await;
        let response = match response {
            Ok(resp) => resp,
            Err(e) => {
                error!("地理位置API请求失败: {}", e);
                self.update_token_usage(&token.id, ip, false).await?;
                return Ok(None);
            }
        };

        if !response.status().is_success() {
            warn!("地理位置API返回错误状态: {}", response.status());
            self.update_token_usage(&token.id, ip, false).await?;
            return Ok(None);
        }

        let ip_info: IpInfoResponse = match response.json().await {
            Ok(data) => data,
            Err(e) => {
                error!("解析地理位置API响应失败: {}", e);
                self.update_token_usage(&token.id, ip, false).await?;
                return Ok(None);
            }
        };

        // 解析经纬度
        let (latitude, longitude) = if let Some(loc) = &ip_info.loc {
            if let Some((lat_str, lon_str)) = loc.split_once(',') {
                match (lat_str.parse::<f64>(), lon_str.parse::<f64>()) {
                    (Ok(lat), Ok(lon)) => (Some(lat), Some(lon)),
                    _ => (None, None),
                }
            } else {
                (None, None)
            }
        } else {
            (None, None)
        };

        let geolocation = UserGeolocation {
            user_id: uuid::Uuid::nil(), // 稍后设置
            ip_address: ip.to_string(),
            latitude,
            longitude,
            country: ip_info.country,
            region: ip_info.region,
            city: ip_info.city,
            isp: ip_info.org,
            timezone: ip_info.timezone,
            zip_code: ip_info.postal,
            geolocation_source: "ipinfo".to_string(),
            updated_at: Utc::now(),
        };

        // 更新token使用统计
        self.update_token_usage(&token.id, ip, true).await?;

        debug!("成功获取IP {} 的地理位置: {:?}", ip, geolocation);
        Ok(Some(geolocation))
    }

    /// 获取用户的地理位置
    pub async fn get_user_geolocation(&self, user_id: &uuid::Uuid) -> Result<Option<UserGeolocation>, AppError> {
        let row = sqlx::query(
            r#"
            SELECT user_id, ip_address::text, latitude, longitude, country, region, city,
                   isp, timezone, zip_code, geolocation_source, updated_at
            FROM user_geolocations
            WHERE user_id = $1
            "#,
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?;

        if let Some(row) = row {
            let geolocation = UserGeolocation {
                user_id: row.try_get("user_id")?,
                ip_address: row.try_get("ip_address")?,
                latitude: row.try_get("latitude")?,
                longitude: row.try_get("longitude")?,
                country: row.try_get("country")?,
                region: row.try_get("region")?,
                city: row.try_get("city")?,
                isp: row.try_get("isp")?,
                timezone: row.try_get("timezone")?,
                zip_code: row.try_get("zip_code")?,
                geolocation_source: row.try_get("geolocation_source")?,
                updated_at: row.try_get("updated_at")?,
            };
            Ok(Some(geolocation))
        } else {
            Ok(None)
        }
    }

    /// 更新用户的地理位置
    pub async fn update_user_geolocation(&self, user_id: &uuid::Uuid, ip: &str, geolocation: &UserGeolocation) -> Result<(), AppError> {
        sqlx::query(
            r#"
            INSERT INTO user_geolocations (
                user_id, ip_address, latitude, longitude, country, region, city,
                isp, timezone, zip_code, geolocation_source, updated_at
            ) VALUES ($1, $2::inet, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            ON CONFLICT (user_id)
            DO UPDATE SET
                ip_address = EXCLUDED.ip_address,
                latitude = EXCLUDED.latitude,
                longitude = EXCLUDED.longitude,
                country = EXCLUDED.country,
                region = EXCLUDED.region,
                city = EXCLUDED.city,
                isp = EXCLUDED.isp,
                timezone = EXCLUDED.timezone,
                zip_code = EXCLUDED.zip_code,
                geolocation_source = EXCLUDED.geolocation_source,
                updated_at = EXCLUDED.updated_at
            "#,
        )
        .bind(user_id)
        .bind(ip)
        .bind(geolocation.latitude)
        .bind(geolocation.longitude)
        .bind(&geolocation.country)
        .bind(&geolocation.region)
        .bind(&geolocation.city)
        .bind(&geolocation.isp)
        .bind(&geolocation.timezone)
        .bind(&geolocation.zip_code)
        .bind(&geolocation.geolocation_source)
        .bind(geolocation.updated_at)
        .execute(&self.pool)
        .await?;

        info!("更新用户 {} 的地理位置: IP={}, 城市={:?}", user_id, ip, geolocation.city);
        Ok(())
    }

    /// 检查用户IP是否变化
    pub async fn has_user_ip_changed(&self, user_id: &uuid::Uuid, current_ip: &str) -> Result<bool, AppError> {
        let row = sqlx::query(
            r#"
            SELECT ip_address::text as ip
            FROM user_geolocations
            WHERE user_id = $1
            "#,
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?;

        if let Some(row) = row {
            let stored_ip: String = row.try_get("ip")?;
            Ok(stored_ip != current_ip)
        } else {
            // 没有记录，认为是变化了
            Ok(true)
        }
    }

    /// 清理过期的token缓存
    pub async fn cleanup_token_cache(&self) {
        let mut cache = self.token_cache.write().await;
        cache.clear();
        debug!("清理了token缓存");
    }

    /// 获取全球用户分布数据（用于地图显示）
    pub async fn get_global_user_distribution(&self) -> Result<Vec<UserLocationMapData>, AppError> {
        let rows = sqlx::query(
            r#"
            SELECT
                ug.latitude,
                ug.longitude,
                ug.country,
                ug.region,
                ug.city,
                ug.user_id,
                u.username,
                u.nickname
            FROM user_geolocations ug
            INNER JOIN users u ON ug.user_id = u.id
            WHERE ug.latitude IS NOT NULL
                AND ug.longitude IS NOT NULL
                AND u.deleted_at IS NULL
            ORDER BY ug.country, ug.region, ug.city
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        // 按地理位置聚合数据
        let mut location_map: std::collections::HashMap<String, UserLocationMapData> =
            std::collections::HashMap::new();

        for row in rows {
            let latitude: f64 = row.try_get("latitude")?;
            let longitude: f64 = row.try_get("longitude")?;
            let country: Option<String> = row.try_get("country")?;
            let region: Option<String> = row.try_get("region")?;
            let city: Option<String> = row.try_get("city")?;
            let user_id: uuid::Uuid = row.try_get("user_id")?;
            let username: String = row.try_get("username")?;
            let nickname: Option<String> = row.try_get("nickname")?;

            // 使用 lat,lng 作为唯一键
            let key = format!("{:.4},{:.4}", latitude, longitude);

            if let Some(location) = location_map.get_mut(&key) {
                location.user_count += 1;
                location.users.push(UserLocationPoint {
                    user_id,
                    username,
                    nickname,
                });
            } else {
                location_map.insert(
                    key.clone(),
                    UserLocationMapData {
                        latitude,
                        longitude,
                        country: country.clone(),
                        region: region.clone(),
                        city: city.clone(),
                        user_count: 1,
                        users: vec![UserLocationPoint {
                            user_id,
                            username,
                            nickname,
                        }],
                    },
                );
            }
        }

        // 转换为向量并按用户数降序排序
        let mut result: Vec<UserLocationMapData> = location_map.into_values().collect();
        result.sort_by(|a, b| b.user_count.cmp(&a.user_count));

        info!("成功获取全球用户分布数据，共 {} 个位置", result.len());
        Ok(result)
    }
}

/// 全局地理位置服务实例
static GEOLOCATION_SERVICE: once_cell::sync::Lazy<std::sync::Mutex<Option<GeolocationService>>> =
    once_cell::sync::Lazy::new(|| std::sync::Mutex::new(None));

/// 初始化地理位置服务
pub fn init_geolocation_service(pool: PgPool) {
    let mut service = GEOLOCATION_SERVICE.lock().unwrap();
    *service = Some(GeolocationService::new(pool));
}

/// 获取地理位置服务实例的克隆
pub fn get_geolocation_service() -> Option<GeolocationService> {
    GEOLOCATION_SERVICE.lock().unwrap().clone()
}
