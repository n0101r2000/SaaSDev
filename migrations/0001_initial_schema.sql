-- =============================================
-- Field OS - 通信人材会社向け運営標準化SaaS
-- 初期スキーマ (マルチテナント対応)
-- =============================================

-- 導入企業
CREATE TABLE IF NOT EXISTS companies (
  company_id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_code TEXT UNIQUE NOT NULL,        -- ログイン用会社コード
  company_name TEXT NOT NULL,
  logo_url TEXT,
  plan TEXT DEFAULT 'basic',                -- basic / standard / premium
  billing_status TEXT DEFAULT 'active',     -- active / overdue / suspended
  user_limit INTEGER DEFAULT 3,
  active_status TEXT DEFAULT 'active',      -- active / trial / inactive
  settings_json TEXT DEFAULT '{}',          -- ランキング表示可否等の企業設定
  maturity_level INTEGER DEFAULT 1,         -- 運営成熟度 1-5
  support_memo TEXT,                        -- 伴走支援メモ
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ユーザー
CREATE TABLE IF NOT EXISTS users (
  user_id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id INTEGER NOT NULL,
  user_code TEXT NOT NULL,                  -- スタッフ番号 / ユーザーID
  name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'staff',       -- system_admin / company_admin / sales_manager / field_manager / office_staff / staff / client_viewer
  password_hash TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  status TEXT DEFAULT 'active',             -- active / suspended
  last_login_at DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(company_id, user_code),
  FOREIGN KEY (company_id) REFERENCES companies(company_id)
);

-- セッション (ログイン状態保持)
CREATE TABLE IF NOT EXISTS sessions (
  token TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  company_id INTEGER NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  expires_at DATETIME NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- スタッフ詳細プロフィール
CREATE TABLE IF NOT EXISTS staff_profiles (
  staff_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER UNIQUE NOT NULL,
  company_id INTEGER NOT NULL,
  affiliation TEXT,                         -- 所属会社
  career TEXT,                              -- 経歴
  skills TEXT,                              -- スキル (カンマ区切り)
  work_area TEXT,                           -- 稼働可能エリア
  age_group TEXT,                           -- 年代
  evaluation_score REAL DEFAULT 0,          -- 総合評価 0-5
  retention_risk TEXT DEFAULT 'low',        -- low / mid / high
  follow_flag INTEGER DEFAULT 0,            -- 要フォロー
  memo TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(user_id),
  FOREIGN KEY (company_id) REFERENCES companies(company_id)
);

-- クライアント
CREATE TABLE IF NOT EXISTS clients (
  client_id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id INTEGER NOT NULL,
  client_name TEXT NOT NULL,
  stream_type TEXT DEFAULT 'upstream',      -- upstream(上流) / downstream(下流)
  contact_name TEXT,
  email TEXT,
  phone TEXT,
  address TEXT,
  contract_type TEXT,                       -- 業務委託 / 派遣 / 請負 / 紹介
  billing_rule TEXT,                        -- 請求締め日・支払条件
  ng_staff_ids TEXT DEFAULT '',             -- NGスタッフID (カンマ区切り)
  client_rating INTEGER DEFAULT 3,          -- クライアント評価 1-5
  memo TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (company_id) REFERENCES companies(company_id)
);

-- 日報テンプレート
CREATE TABLE IF NOT EXISTS report_templates (
  template_id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id INTEGER,                       -- NULL = 本部配信の共通テンプレート
  template_name TEXT NOT NULL,
  template_type TEXT DEFAULT 'custom',      -- hq(本部配信) / custom(企業独自)
  fields_json TEXT NOT NULL,                -- 項目定義JSON
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 案件
CREATE TABLE IF NOT EXISTS projects (
  project_id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id INTEGER NOT NULL,
  client_id INTEGER,
  project_name TEXT NOT NULL,
  project_type TEXT DEFAULT 'mobile_shop',  -- mobile_shop / electronics / event / fiber / fixed_line / callcenter / other
  location TEXT,
  location_lat REAL,
  location_lng REAL,
  unit_price_type TEXT DEFAULT 'daily',     -- monthly / daily / hourly / performance
  unit_price INTEGER DEFAULT 0,
  required_skills TEXT,
  report_template_id INTEGER,
  show_performance INTEGER DEFAULT 1,       -- スタッフへの実績表示可否
  manual_text TEXT,                         -- 案件マニュアル・注意事項
  requirements TEXT,                        -- 求められる内容
  status TEXT DEFAULT 'active',             -- active / closed
  memo TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (company_id) REFERENCES companies(company_id),
  FOREIGN KEY (client_id) REFERENCES clients(client_id)
);

-- シフト
CREATE TABLE IF NOT EXISTS shifts (
  shift_id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id INTEGER NOT NULL,
  staff_id INTEGER NOT NULL,                -- staff_profiles.staff_id
  project_id INTEGER NOT NULL,
  work_date DATE NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  location TEXT,
  role TEXT,
  unit_price INTEGER DEFAULT 0,
  transportation_fee INTEGER DEFAULT 0,
  status TEXT DEFAULT 'confirmed',          -- requested(希望) / confirmed(確定) / absent(欠勤) / substitute(代打)
  registered_by INTEGER,
  memo TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (company_id) REFERENCES companies(company_id),
  FOREIGN KEY (staff_id) REFERENCES staff_profiles(staff_id),
  FOREIGN KEY (project_id) REFERENCES projects(project_id)
);

-- 勤怠報告 (起床/出発/入店/退店)
CREATE TABLE IF NOT EXISTS attendance_reports (
  attendance_id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id INTEGER NOT NULL,
  staff_id INTEGER NOT NULL,
  shift_id INTEGER NOT NULL,
  report_type TEXT NOT NULL,                -- wake_up / departure / check_in / check_out
  reported_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  latitude REAL,
  longitude REAL,
  address TEXT,
  device_info TEXT,
  status TEXT DEFAULT 'normal',             -- normal / late / no_location
  UNIQUE(shift_id, report_type),
  FOREIGN KEY (company_id) REFERENCES companies(company_id),
  FOREIGN KEY (staff_id) REFERENCES staff_profiles(staff_id),
  FOREIGN KEY (shift_id) REFERENCES shifts(shift_id)
);

-- 日報
CREATE TABLE IF NOT EXISTS daily_reports (
  daily_report_id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id INTEGER NOT NULL,
  staff_id INTEGER NOT NULL,
  project_id INTEGER NOT NULL,
  shift_id INTEGER,
  work_date DATE NOT NULL,
  report_values TEXT NOT NULL DEFAULT '{}', -- 入力内容JSON
  incident_flag INTEGER DEFAULT 0,
  complaint_flag INTEGER DEFAULT 0,
  manager_comment TEXT,
  manager_checked INTEGER DEFAULT 0,        -- 管理者確認済み
  submitted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (company_id) REFERENCES companies(company_id),
  FOREIGN KEY (staff_id) REFERENCES staff_profiles(staff_id),
  FOREIGN KEY (project_id) REFERENCES projects(project_id)
);

-- 評価
CREATE TABLE IF NOT EXISTS evaluations (
  evaluation_id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id INTEGER NOT NULL,
  staff_id INTEGER NOT NULL,
  evaluator_id INTEGER,
  evaluation_period TEXT,                   -- 例: 2026-06
  attendance_score INTEGER DEFAULT 3,
  report_score INTEGER DEFAULT 3,
  performance_score INTEGER DEFAULT 3,
  client_score INTEGER DEFAULT 3,
  growth_score INTEGER DEFAULT 3,
  retention_score INTEGER DEFAULT 3,
  comment TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (company_id) REFERENCES companies(company_id),
  FOREIGN KEY (staff_id) REFERENCES staff_profiles(staff_id)
);

-- フォロー履歴
CREATE TABLE IF NOT EXISTS follow_logs (
  follow_id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id INTEGER NOT NULL,
  staff_id INTEGER NOT NULL,
  manager_id INTEGER,
  follow_type TEXT NOT NULL,                -- interview / phone / line / warning / praise / training / claim / health / shift / career / round
  content TEXT,
  next_action TEXT,
  status TEXT DEFAULT 'open',               -- open / done
  related_project_id INTEGER,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (company_id) REFERENCES companies(company_id),
  FOREIGN KEY (staff_id) REFERENCES staff_profiles(staff_id)
);

-- お知らせ
CREATE TABLE IF NOT EXISTS notices (
  notice_id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  target_type TEXT DEFAULT 'all',           -- all / project / staff
  target_ids TEXT DEFAULT '',
  importance TEXT DEFAULT 'normal',         -- normal / important / urgent
  read_required INTEGER DEFAULT 0,
  published_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by INTEGER,
  FOREIGN KEY (company_id) REFERENCES companies(company_id)
);

-- お知らせ既読
CREATE TABLE IF NOT EXISTS notice_reads (
  notice_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  read_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (notice_id, user_id)
);

-- 相談・連絡
CREATE TABLE IF NOT EXISTS consultations (
  consultation_id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id INTEGER NOT NULL,
  staff_id INTEGER NOT NULL,
  category TEXT NOT NULL,                   -- health / absence / store_trouble / claim / relationship / shift / question / other
  body TEXT NOT NULL,
  urgency TEXT DEFAULT 'normal',            -- low / normal / high
  target_project_id INTEGER,
  target_date DATE,
  manager_reply TEXT,
  status TEXT DEFAULT 'open',               -- open / in_progress / done
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (company_id) REFERENCES companies(company_id),
  FOREIGN KEY (staff_id) REFERENCES staff_profiles(staff_id)
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_users_company ON users(company_id);
CREATE INDEX IF NOT EXISTS idx_shifts_company_date ON shifts(company_id, work_date);
CREATE INDEX IF NOT EXISTS idx_shifts_staff ON shifts(staff_id, work_date);
CREATE INDEX IF NOT EXISTS idx_attendance_shift ON attendance_reports(shift_id);
CREATE INDEX IF NOT EXISTS idx_daily_reports_company_date ON daily_reports(company_id, work_date);
CREATE INDEX IF NOT EXISTS idx_daily_reports_staff ON daily_reports(staff_id);
CREATE INDEX IF NOT EXISTS idx_notices_company ON notices(company_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions(expires_at);
