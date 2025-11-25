-- 添加hostname字段到user_geolocations表
ALTER TABLE user_geolocations 
ADD COLUMN hostname TEXT;

-- 添加注释
COMMENT ON COLUMN user_geolocations.hostname IS '主机名，从ipinfo.io获取';
