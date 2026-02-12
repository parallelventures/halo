-- App Config table for remote feature flags
-- Used to control app behavior without submitting new builds

CREATE TABLE IF NOT EXISTS app_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read config
CREATE POLICY "Anyone can read app_config"
    ON app_config FOR SELECT
    USING (true);

-- Insert the AI consent flag (set to 'true' for Apple review)
INSERT INTO app_config (key, value, description)
VALUES ('show_ai_consent', 'true', 'Show AI data consent sheet before first generation. Set to false after Apple approval.')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- After Apple approves, run this to disable the consent sheet:
-- UPDATE app_config SET value = 'false', updated_at = NOW() WHERE key = 'show_ai_consent';
