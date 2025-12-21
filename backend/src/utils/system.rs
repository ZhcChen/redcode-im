use crate::error::AppError;
use std::fs;

pub async fn get_system_load() -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
    #[cfg(unix)]
    {
        let load_avg = fs::read_to_string("/proc/loadavg")?;
        let load_str = load_avg.split_whitespace().next().unwrap_or("0.0");
        Ok(load_str.parse::<f64>().unwrap_or(0.0))
    }
    #[cfg(not(unix))]
    {
        Ok(0.0)
    }
}

pub async fn get_memory_usage() -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
    #[cfg(unix)]
    {
        let meminfo = fs::read_to_string("/proc/meminfo")?;
        let mut total_memory = 0u64;
        let mut free_memory = 0u64;
        let mut available_memory = 0u64;

        for line in meminfo.lines() {
            if line.starts_with("MemTotal:") {
                total_memory = line
                    .split_whitespace()
                    .nth(1)
                    .unwrap_or("0")
                    .parse::<u64>()
                    .unwrap_or(0);
            } else if line.starts_with("MemFree:") {
                free_memory = line
                    .split_whitespace()
                    .nth(1)
                    .unwrap_or("0")
                    .parse::<u64>()
                    .unwrap_or(0);
            } else if line.starts_with("MemAvailable:") {
                available_memory = line
                    .split_whitespace()
                    .nth(1)
                    .unwrap_or("0")
                    .parse::<u64>()
                    .unwrap_or(0);
            }
        }

        let used = if available_memory > 0 {
            total_memory - available_memory
        } else {
            total_memory - free_memory
        };

        if total_memory == 0 {
            return Ok(0.0);
        }

        Ok((used as f64) / (total_memory as f64))
    }
    #[cfg(not(unix))]
    {
        Ok(0.0)
    }
}

pub async fn get_disk_usage() -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
    // 简化的模拟实现
    Ok(0.28)
}

pub async fn get_network_stats() -> Result<(f64, f64), Box<dyn std::error::Error + Send + Sync>> {
    #[cfg(unix)]
    {
        let net_dev = fs::read_to_string("/proc/net/dev")?;
        let mut total_rx = 0u64;
        let mut total_tx = 0u64;

        for line in net_dev.lines().skip(2) {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() > 16 {
                if !line.contains("lo:") {
                    total_rx += parts[1].parse::<u64>().unwrap_or(0);
                    total_tx += parts[9].parse::<u64>().unwrap_or(0);
                }
            }
        }

        Ok((total_rx as f64, total_tx as f64))
    }
    #[cfg(not(unix))]
    {
        Ok((512000.0, 256000.0))
    }
}

pub async fn get_active_connections() -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
    #[cfg(unix)]
    {
        let tcp_content = fs::read_to_string("/proc/net/tcp")?;
        let udp_content = fs::read_to_string("/proc/net/udp")?;

        let tcp_connections = tcp_content.lines().count() as i64 - 1;
        let udp_connections = udp_content.lines().count() as i64 - 1;

        Ok(tcp_connections + udp_connections)
    }
    #[cfg(not(unix))]
    {
        Ok(68)
    }
}

pub async fn get_system_uptime() -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
    #[cfg(unix)]
    {
        let uptime_content = fs::read_to_string("/proc/uptime")?;
        let uptime_seconds = uptime_content
            .split_whitespace()
            .next()
            .unwrap_or("0")
            .parse::<f64>()
            .unwrap_or(0.0);
        Ok(uptime_seconds as i64)
    }
    #[cfg(not(unix))]
    {
        Ok(86400)
    }
}

pub async fn get_load_average() -> Result<Vec<f64>, Box<dyn std::error::Error + Send + Sync>> {
    #[cfg(unix)]
    {
        let load_avg = fs::read_to_string("/proc/loadavg")?;
        let loads: Vec<f64> = load_avg
            .split_whitespace()
            .take(3)
            .map(|s| s.parse::<f64>().unwrap_or(0.0))
            .collect();
        Ok(loads)
    }
    #[cfg(not(unix))]
    {
        Ok(vec![0.5, 0.3, 0.2])
    }
}
