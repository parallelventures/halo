-- ============================================
-- HALO - Supabase Tables for Onboarding & Preferences
-- ============================================

-- 1. USER PREFERENCES
-- Stores user's style category preference (men/women)
CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    style_category TEXT NOT NULL CHECK (style_category IN ('men', 'women')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- Users can only access their own preferences
CREATE POLICY "Users can view own preferences"
    ON user_preferences FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own preferences"
    ON user_preferences FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own preferences"
    ON user_preferences FOR UPDATE
    USING (auth.uid() = user_id);


-- 2. LIKED STYLES
-- Stores styles that user liked during onboarding swipe
CREATE TABLE IF NOT EXISTS liked_styles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    style_name TEXT NOT NULL,
    style_category TEXT NOT NULL CHECK (style_category IN ('men', 'women')),
    liked_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE liked_styles ENABLE ROW LEVEL SECURITY;

-- Users can only access their own liked styles
CREATE POLICY "Users can view own liked styles"
    ON liked_styles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own liked styles"
    ON liked_styles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own liked styles"
    ON liked_styles FOR DELETE
    USING (auth.uid() = user_id);


-- 3. ONBOARDING EVENTS (Analytics)
-- Tracks user progress through onboarding
CREATE TABLE IF NOT EXISTS onboarding_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT, -- For anonymous tracking before login
    event_name TEXT NOT NULL,
    event_data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE onboarding_events ENABLE ROW LEVEL SECURITY;

-- Only insert allowed (analytics, no read needed from client)
CREATE POLICY "Users can insert own events"
    ON onboarding_events FOR INSERT
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL);


-- ============================================
-- INDEXES for performance
-- ============================================
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id ON user_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_liked_styles_user_id ON liked_styles(user_id);
CREATE INDEX IF NOT EXISTS idx_onboarding_events_user_id ON onboarding_events(user_id);
CREATE INDEX IF NOT EXISTS idx_onboarding_events_device_id ON onboarding_events(device_id);


-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to update user preferences (upsert)
CREATE OR REPLACE FUNCTION upsert_user_preference(
    p_user_id UUID,
    p_style_category TEXT
)
RETURNS void AS $$
BEGIN
    INSERT INTO public.user_preferences (user_id, style_category)
    VALUES (p_user_id, p_style_category)
    ON CONFLICT (user_id) 
    DO UPDATE SET 
        style_category = p_style_category,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
