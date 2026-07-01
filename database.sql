-- 随手记数据库表结构
-- 在 Supabase SQL Editor 中执行此文件

-- 1. 岗位表
CREATE TABLE IF NOT EXISTS positions (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. 用户表
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  position_id INTEGER REFERENCES positions(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. 记录表
CREATE TABLE IF NOT EXISTS records (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  record_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 启用行级安全（RLS）
ALTER TABLE positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE records ENABLE ROW LEVEL SECURITY;

-- 创建策略：允许所有操作（因为是个人使用，简单起见）
CREATE POLICY "Enable all access for positions" ON positions FOR ALL USING (true);
CREATE POLICY "Enable all access for users" ON users FOR ALL USING (true);
CREATE POLICY "Enable all access for records" ON records FOR ALL USING (true);

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_records_user_id ON records(user_id);
CREATE INDEX IF NOT EXISTS idx_records_date ON records(record_date);
CREATE INDEX IF NOT EXISTS idx_users_position_id ON users(position_id);

-- 插入示例岗位（可选）
INSERT INTO positions (name) VALUES 
  ('法务'),
  ('厨师')
ON CONFLICT (name) DO NOTHING;

-- 删除不需要的预设岗位
DELETE FROM positions WHERE name IN ('产品经理', '开发工程师', '测试工程师', '设计师', '运营');

-- 创建更新 updated_at 的触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为 records 表添加 updated_at 触发器
CREATE TRIGGER update_records_updated_at
  BEFORE UPDATE ON records
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
