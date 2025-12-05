-- 支持每个房间多条消息置顶
-- 将 room_pins 主键从单列 room_id 调整为联合主键 (room_id, message_id)

ALTER TABLE room_pins
  DROP CONSTRAINT IF EXISTS room_pins_pkey;

ALTER TABLE room_pins
  ADD CONSTRAINT room_pins_pkey PRIMARY KEY (room_id, message_id);

