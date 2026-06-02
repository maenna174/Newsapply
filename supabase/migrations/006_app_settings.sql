create table if not exists app_settings (
  setting_key text primary key,
  value jsonb not null,
  is_secret boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table app_settings enable row level security;
