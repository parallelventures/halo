-- ============================================
-- ECLAT - Auto-Create Profile & Entitlements
-- This trigger ensures every new auth user gets a profile and entitlements record
-- CRITICAL: Without this, users can pay but have no database record!
-- ============================================

-- 1) Add missing columns to profiles table if they don't exist
DO $$ 
BEGIN
    -- email column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'email') THEN
        ALTER TABLE public.profiles ADD COLUMN email text;
    END IF;
    
    -- full_name column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'full_name') THEN
        ALTER TABLE public.profiles ADD COLUMN full_name text;
    END IF;
    
    -- created_at column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'created_at') THEN
        ALTER TABLE public.profiles ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();
    END IF;
    
    -- updated_at column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'updated_at') THEN
        ALTER TABLE public.profiles ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();
    END IF;
END $$;


-- 2) Function to handle new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  -- Create profile (use UPSERT to handle existing records)
  INSERT INTO public.profiles (id)
  VALUES (NEW.id)
  ON CONFLICT (id) DO UPDATE SET
    updated_at = COALESCE(public.profiles.updated_at, NOW());
  
  -- Update email and full_name if columns exist
  BEGIN
    UPDATE public.profiles 
    SET 
      email = COALESCE(NEW.email, public.profiles.email),
      full_name = COALESCE(
        NEW.raw_user_meta_data->>'full_name', 
        NEW.raw_user_meta_data->>'name',
        public.profiles.full_name
      ),
      updated_at = NOW()
    WHERE id = NEW.id;
  EXCEPTION WHEN undefined_column THEN
    -- Columns don't exist, skip update
    NULL;
  END;
  
  -- Create entitlements
  INSERT INTO public.entitlements (user_id, looks_balance, updated_at)
  VALUES (NEW.id, 0, NOW())
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- 3) Create trigger on auth.users (drop first if exists)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- 4) Backfill: Create entitlements for existing users who don't have them
INSERT INTO public.entitlements (user_id, looks_balance, updated_at)
SELECT id, 0, NOW()
FROM auth.users
WHERE id NOT IN (SELECT user_id FROM public.entitlements)
ON CONFLICT (user_id) DO NOTHING;

-- 5) Backfill: Create profiles for existing users who don't have them
INSERT INTO public.profiles (id)
SELECT id
FROM auth.users
WHERE id NOT IN (SELECT id FROM public.profiles)
ON CONFLICT (id) DO NOTHING;


-- ============================================
-- VERIFICATION
-- ============================================
SELECT 
  'Profiles count: ' || COUNT(*) as profiles_status
FROM public.profiles;

SELECT 
  'Entitlements count: ' || COUNT(*) as entitlements_status
FROM public.entitlements;

SELECT 'Migration completed! All users now have profile and entitlements records.' as status;
