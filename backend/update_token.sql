-- 更新ipinfo.io token为真实值
-- 请将 YOUR_REAL_IPINFO_TOKEN 替换为你的实际token
UPDATE ipinfo_tokens 
SET token = 'YOUR_REAL_IPINFO_TOKEN', 
    updated_at = NOW() 
WHERE name = 'default_token';
