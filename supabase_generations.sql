-- ============================================
-- HALO - Additional Tables (Generations & History)
-- Run this AFTER supabase_tables.sql
-- ============================================

-- ============================================
-- 1. GENERATIONS TABLE
-- Stores all AI-generated hairstyle images
-- ============================================
CREATE TABLE IF NOT EXISTS generations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Images
    original_image_url TEXT,           -- User's selfie (stored in Supabase Storage)
    generated_image_url TEXT,          -- AI-generated result
    thumbnail_url TEXT,                -- Thumbnail for list view
    
    -- Style info
    style_name TEXT,                   -- e.g. "Textured Crop", "Low Fade"
    style_category TEXT CHECK (style_category IN ('men', 'women')),
    style_prompt TEXT,                 -- The prompt sent to Gemini API
    
    -- Metadata
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    error_message TEXT,                -- If status = 'failed'
    processing_time_ms INTEGER,        -- How long it took to generate
    
    -- User interaction
    is_favorite BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,  -- Soft delete
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE generations ENABLE ROW LEVEL SECURITY;

-- Users can only access their own generations
CREATE POLICY "Users can view own generations"
    ON generations FOR SELECT
    USING (auth.uid() = user_id AND is_deleted = FALSE);

CREATE POLICY "Users can insert own generations"
    ON generations FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own generations"
    ON generations FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own generations"
    ON generations FOR DELETE
    USING (auth.uid() = user_id);


-- ============================================
-- 2. STORAGE BUCKET FOR IMAGES
-- Run in Supabase Dashboard > Storage
-- ============================================
-- Create bucket 'generations' with these settings:
-- - Public: false (requires auth)
-- - File size limit: 10MB
-- - Allowed MIME types: image/jpeg, image/png, image/heic, image/webp

-- Storage policies (run in SQL editor):
INSERT INTO storage.buckets (id, name, public)
VALUES ('generations', 'generations', false)
ON CONFLICT (id) DO NOTHING;

-- Allow users to upload to their own folder
CREATE POLICY "Users can upload own images"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'generations' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Allow users to view their own images
CREATE POLICY "Users can view own images"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'generations' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Allow users to delete their own images
CREATE POLICY "Users can delete own images"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'generations' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );


-- ============================================
-- 3. USER PROFILES (Extended user info)
-- ============================================
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    
    -- Profile info
    display_name TEXT,
    avatar_url TEXT,
    
    -- Subscription status (synced from RevenueCat)
    is_subscribed BOOLEAN DEFAULT FALSE,
    subscription_tier TEXT CHECK (subscription_tier IN ('free', 'monthly', 'annual')),
    subscription_expires_at TIMESTAMPTZ,
    
    -- Stats
    total_generations INTEGER DEFAULT 0,
    generations_this_month INTEGER DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
    ON user_profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile"
    ON user_profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
    ON user_profiles FOR UPDATE
    USING (auth.uid() = user_id);


-- ============================================
-- 4. INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_generations_user_id ON generations(user_id);
CREATE INDEX IF NOT EXISTS idx_generations_created_at ON generations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_generations_status ON generations(status);
CREATE INDEX IF NOT EXISTS idx_generations_is_favorite ON generations(is_favorite) WHERE is_favorite = TRUE;
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);


-- ============================================
-- 5. FUNCTIONS
-- ============================================

-- Function to increment generation count
CREATE OR REPLACE FUNCTION increment_generation_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE user_profiles
    SET 
        total_generations = total_generations + 1,
        generations_this_month = generations_this_month + 1,
        updated_at = NOW()
    WHERE user_id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-increment on new generation
DROP TRIGGER IF EXISTS on_generation_created ON generations;
CREATE TRIGGER on_generation_created
    AFTER INSERT ON generations
    FOR EACH ROW
    EXECUTE FUNCTION increment_generation_count();


-- Function to create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_profiles (user_id, display_name)
    VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'name', NEW.email));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-create profile on signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();


-- Function to reset monthly generation count (run via cron)
CREATE OR REPLACE FUNCTION reset_monthly_generations()
RETURNS void AS $$
BEGIN
    UPDATE user_profiles
    SET generations_this_month = 0, updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================
-- 6. VIEWS (Optional - for easier queries)
-- ============================================

-- View for user's generation history
CREATE OR REPLACE VIEW user_generation_history AS
SELECT 
    g.id,
    g.user_id,
    g.generated_image_url,
    g.thumbnail_url,
    g.style_name,
    g.style_category,
    g.is_favorite,
    g.created_at,
    p.display_name as user_name
FROM generations g
LEFT JOIN user_profiles p ON g.user_id = p.user_id
WHERE g.is_deleted = FALSE AND g.status = 'completed';
