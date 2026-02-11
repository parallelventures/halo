-- ============================================
-- ECLAT - Monetization Engine v2.0
-- SAFE MIGRATION - Adds columns to existing tables
-- ============================================

-- ============================================
-- 1) ADD COLUMNS TO EXISTING PROFILES TABLE
-- ============================================

-- Add segmentation columns if they don't exist
DO $$ 
BEGIN
    -- primary_segment
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'primary_segment') THEN
        ALTER TABLE public.profiles ADD COLUMN primary_segment text NOT NULL DEFAULT 'TOURIST';
    END IF;
    
    -- lifecycle_state
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'lifecycle_state') THEN
        ALTER TABLE public.profiles ADD COLUMN lifecycle_state text NOT NULL DEFAULT 'NEW';
    END IF;
    
    -- tags
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'tags') THEN
        ALTER TABLE public.profiles ADD COLUMN tags text[] NOT NULL DEFAULT '{}';
    END IF;
    
    -- churn_risk_score
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'churn_risk_score') THEN
        ALTER TABLE public.profiles ADD COLUMN churn_risk_score int NOT NULL DEFAULT 0;
    END IF;
    
    -- abuse_score
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'abuse_score') THEN
        ALTER TABLE public.profiles ADD COLUMN abuse_score int NOT NULL DEFAULT 0;
    END IF;
    
    -- total_sessions
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'total_sessions') THEN
        ALTER TABLE public.profiles ADD COLUMN total_sessions int NOT NULL DEFAULT 0;
    END IF;
    
    -- looks_used_total
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'looks_used_total') THEN
        ALTER TABLE public.profiles ADD COLUMN looks_used_total int NOT NULL DEFAULT 0;
    END IF;
    
    -- saves_count
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'saves_count') THEN
        ALTER TABLE public.profiles ADD COLUMN saves_count int NOT NULL DEFAULT 0;
    END IF;
    
    -- shares_count
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'shares_count') THEN
        ALTER TABLE public.profiles ADD COLUMN shares_count int NOT NULL DEFAULT 0;
    END IF;
    
    -- last_generation_at
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'last_generation_at') THEN
        ALTER TABLE public.profiles ADD COLUMN last_generation_at timestamptz;
    END IF;
    
    -- last_seen_at
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'last_seen_at') THEN
        ALTER TABLE public.profiles ADD COLUMN last_seen_at timestamptz;
    END IF;
    
    -- marketing_source
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'marketing_source') THEN
        ALTER TABLE public.profiles ADD COLUMN marketing_source text;
    END IF;
END $$;


-- ============================================
-- 2) ENTITLEMENTS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS public.entitlements (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  looks_balance int NOT NULL DEFAULT 0,
  
  -- Creator Mode (weekly subscription)
  creator_mode_active boolean NOT NULL DEFAULT false,
  creator_mode_renewal_at timestamptz,
  creator_mode_daily_used int NOT NULL DEFAULT 0,
  creator_mode_last_reset_date date,
  
  -- Quality & features
  quality_tier text NOT NULL DEFAULT 'standard',
  watermark_disabled boolean NOT NULL DEFAULT false,
  
  -- Entry access tracking
  has_entry_access boolean NOT NULL DEFAULT false,
  entry_purchased_at timestamptz,
  
  -- Pack purchase tracking
  total_packs_purchased int NOT NULL DEFAULT 0,
  last_pack_purchased_at timestamptz,
  
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.entitlements ENABLE ROW LEVEL SECURITY;

-- RLS Policies (drop if exist to avoid errors)
DROP POLICY IF EXISTS "Users can view own entitlements" ON public.entitlements;
CREATE POLICY "Users can view own entitlements"
  ON public.entitlements FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own entitlements" ON public.entitlements;
CREATE POLICY "Users can insert own entitlements"
  ON public.entitlements FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own entitlements" ON public.entitlements;
CREATE POLICY "Users can update own entitlements"
  ON public.entitlements FOR UPDATE
  USING (auth.uid() = user_id);


-- ============================================
-- 3) MONETIZATION EVENTS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS public.monetization_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  
  event_type text NOT NULL,
  product_id text NOT NULL,
  
  revenue_usd numeric(10,2),
  currency text,
  looks_granted int,
  
  platform text NOT NULL DEFAULT 'ios',
  raw_payload jsonb
);

CREATE INDEX IF NOT EXISTS idx_monetization_events_user_created 
  ON public.monetization_events(user_id, created_at DESC);

ALTER TABLE public.monetization_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own monetization events" ON public.monetization_events;
CREATE POLICY "Users can view own monetization events"
  ON public.monetization_events FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert monetization events" ON public.monetization_events;
CREATE POLICY "Users can insert monetization events"
  ON public.monetization_events FOR INSERT
  WITH CHECK (auth.uid() = user_id);


-- ============================================
-- 4) OFFER IMPRESSIONS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS public.offer_impressions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  
  offer_key text NOT NULL,
  surface text NOT NULL,
  action_taken text,
  context jsonb
);

CREATE INDEX IF NOT EXISTS idx_offer_impressions_user_created 
  ON public.offer_impressions(user_id, created_at DESC);

ALTER TABLE public.offer_impressions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own impressions" ON public.offer_impressions;
CREATE POLICY "Users can view own impressions"
  ON public.offer_impressions FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own impressions" ON public.offer_impressions;
CREATE POLICY "Users can insert own impressions"
  ON public.offer_impressions FOR INSERT
  WITH CHECK (auth.uid() = user_id);


-- ============================================
-- 5) ADD COLUMNS TO EXISTING GENERATIONS TABLE
-- ============================================

DO $$ 
BEGIN
    -- is_saved
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'generations' AND column_name = 'is_saved') THEN
        ALTER TABLE public.generations ADD COLUMN is_saved boolean NOT NULL DEFAULT false;
    END IF;
    
    -- is_shared
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'generations' AND column_name = 'is_shared') THEN
        ALTER TABLE public.generations ADD COLUMN is_shared boolean NOT NULL DEFAULT false;
    END IF;
    
    -- is_favorite
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'generations' AND column_name = 'is_favorite') THEN
        ALTER TABLE public.generations ADD COLUMN is_favorite boolean NOT NULL DEFAULT false;
    END IF;
    
    -- quality_tier
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'generations' AND column_name = 'quality_tier') THEN
        ALTER TABLE public.generations ADD COLUMN quality_tier text NOT NULL DEFAULT 'standard';
    END IF;
END $$;


-- ============================================
-- 6) STYLES CATALOG TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS public.styles (
  id text PRIMARY KEY,
  gender text NOT NULL,
  name text NOT NULL,
  category text,
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  tags text[] NOT NULL DEFAULT '{}',
  image_name text,
  prompt_json text,
  created_at timestamptz NOT NULL DEFAULT now()
);


-- ============================================
-- 7) HELPER FUNCTIONS
-- ============================================

-- Function: Compute primary segment based on behavior
CREATE OR REPLACE FUNCTION public.compute_primary_segment(
  p_user_id uuid
) RETURNS text AS $$
DECLARE
  v_has_entry boolean := false;
  v_total_packs int := 0;
  v_looks_used int := 0;
  v_sessions int := 0;
  v_saves int := 0;
  v_creator_active boolean := false;
BEGIN
  -- Get entitlements data
  SELECT 
    COALESCE(e.has_entry_access, false),
    COALESCE(e.total_packs_purchased, 0),
    COALESCE(e.creator_mode_active, false)
  INTO v_has_entry, v_total_packs, v_creator_active
  FROM public.entitlements e
  WHERE e.user_id = p_user_id;
  
  -- Get profile data
  SELECT 
    COALESCE(p.looks_used_total, 0),
    COALESCE(p.total_sessions, 0),
    COALESCE(p.saves_count, 0)
  INTO v_looks_used, v_sessions, v_saves
  FROM public.profiles p
  WHERE p.id = p_user_id;
  
  -- POWER: weekly sub OR (looks_used >= 30 AND repeat buyer)
  IF v_creator_active OR (v_looks_used >= 30 AND v_total_packs >= 2) THEN
    RETURN 'POWER';
  END IF;
  
  -- BUYER: at least 1 pack purchase
  IF v_total_packs >= 1 THEN
    RETURN 'BUYER';
  END IF;
  
  -- EXPLORER: looks_used >= 8 OR saves >= 2 OR sessions >= 2
  IF v_looks_used >= 8 OR v_saves >= 2 OR v_sessions >= 2 THEN
    RETURN 'EXPLORER';
  END IF;
  
  -- SAMPLER: entry_purchase OR looks_used 3-7
  IF v_has_entry OR v_looks_used >= 3 THEN
    RETURN 'SAMPLER';
  END IF;
  
  -- Default: TOURIST
  RETURN 'TOURIST';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Function: Check if cooldown is active for an offer
CREATE OR REPLACE FUNCTION public.check_offer_cooldown(
  p_user_id uuid,
  p_offer_key text,
  p_same_offer_hours int DEFAULT 24,
  p_any_offer_hours int DEFAULT 4
) RETURNS boolean AS $$
DECLARE
  v_last_same_offer timestamptz;
  v_last_any_offer timestamptz;
BEGIN
  -- Check last impression of same offer
  SELECT created_at INTO v_last_same_offer
  FROM public.offer_impressions
  WHERE user_id = p_user_id AND offer_key = p_offer_key
  ORDER BY created_at DESC
  LIMIT 1;
  
  IF v_last_same_offer IS NOT NULL AND 
     v_last_same_offer > now() - (p_same_offer_hours || ' hours')::interval THEN
    RETURN true;
  END IF;
  
  -- Check last impression of any offer
  SELECT created_at INTO v_last_any_offer
  FROM public.offer_impressions
  WHERE user_id = p_user_id
  ORDER BY created_at DESC
  LIMIT 1;
  
  IF v_last_any_offer IS NOT NULL AND 
     v_last_any_offer > now() - (p_any_offer_hours || ' hours')::interval THEN
    RETURN true;
  END IF;
  
  RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Function: Count daily impressions
CREATE OR REPLACE FUNCTION public.count_daily_impressions(
  p_user_id uuid
) RETURNS int AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::int
    FROM public.offer_impressions
    WHERE user_id = p_user_id
      AND created_at > date_trunc('day', now())
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================
-- 8) INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_profiles_primary_segment ON public.profiles(primary_segment);
CREATE INDEX IF NOT EXISTS idx_profiles_lifecycle_state ON public.profiles(lifecycle_state);
CREATE INDEX IF NOT EXISTS idx_entitlements_creator_mode ON public.entitlements(creator_mode_active);
CREATE INDEX IF NOT EXISTS idx_offer_impressions_offer_key ON public.offer_impressions(offer_key, user_id);


-- ============================================
-- 9) CREATE ENTITLEMENTS FOR EXISTING USERS
-- ============================================

INSERT INTO public.entitlements (user_id)
SELECT id FROM auth.users
WHERE id NOT IN (SELECT user_id FROM public.entitlements)
ON CONFLICT (user_id) DO NOTHING;


-- ============================================
-- 10) PUSH NOTIFICATION SYSTEM
-- ============================================

-- Add push columns to profiles
DO $$ 
BEGIN
    -- push_enabled
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'push_enabled') THEN
        ALTER TABLE public.profiles ADD COLUMN push_enabled boolean NOT NULL DEFAULT false;
    END IF;
    
    -- last_push_at
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'last_push_at') THEN
        ALTER TABLE public.profiles ADD COLUMN last_push_at timestamptz;
    END IF;
    
    -- push_fatigue_score
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'push_fatigue_score') THEN
        ALTER TABLE public.profiles ADD COLUMN push_fatigue_score int NOT NULL DEFAULT 0;
    END IF;
    
    -- timezone (for local time scheduling)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'timezone') THEN
        ALTER TABLE public.profiles ADD COLUMN timezone text DEFAULT 'UTC';
    END IF;
    
    -- installed_at (for T+X scheduling)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'installed_at') THEN
        ALTER TABLE public.profiles ADD COLUMN installed_at timestamptz;
    END IF;
    
    -- first_result_at
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'first_result_at') THEN
        ALTER TABLE public.profiles ADD COLUMN first_result_at timestamptz;
    END IF;
    
    -- entry_purchased_at
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'entry_purchased_at') THEN
        ALTER TABLE public.profiles ADD COLUMN entry_purchased_at timestamptz;
    END IF;
END $$;


-- Notification log table
CREATE TABLE IF NOT EXISTS public.notification_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  
  notif_key text NOT NULL,          -- e.g. 'tourist_t24', 'explorer_evening'
  segment text NOT NULL,
  copy_variant text,                -- 'A' or 'B' for A/B testing
  deep_link text,
  
  scheduled_for timestamptz,
  delivered boolean NOT NULL DEFAULT false,
  delivered_at timestamptz,
  opened boolean NOT NULL DEFAULT false,
  opened_at timestamptz,
  
  -- Outcome tracking
  generated_after boolean DEFAULT false,
  purchased_after boolean DEFAULT false,
  
  context jsonb
);

CREATE INDEX IF NOT EXISTS idx_notification_log_user_created 
  ON public.notification_log(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notification_log_notif_key 
  ON public.notification_log(notif_key);

ALTER TABLE public.notification_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notifications" ON public.notification_log;
CREATE POLICY "Users can view own notifications"
  ON public.notification_log FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service can insert notifications" ON public.notification_log;
CREATE POLICY "Service can insert notifications"
  ON public.notification_log FOR INSERT
  WITH CHECK (true);  -- Server inserts via service role


-- Push tokens table
CREATE TABLE IF NOT EXISTS public.push_tokens (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token text NOT NULL,
  platform text NOT NULL DEFAULT 'ios',
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(user_id, token)
);

ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own tokens" ON public.push_tokens;
CREATE POLICY "Users can manage own tokens"
  ON public.push_tokens FOR ALL
  USING (auth.uid() = user_id);


-- Function: Check push eligibility (cooldown + caps)
CREATE OR REPLACE FUNCTION public.check_push_eligibility(
  p_user_id uuid
) RETURNS boolean AS $$
DECLARE
  v_last_push_at timestamptz;
  v_pushes_today int;
  v_pushes_this_week int;
  v_push_enabled boolean;
BEGIN
  -- Get profile data
  SELECT push_enabled, last_push_at
  INTO v_push_enabled, v_last_push_at
  FROM public.profiles
  WHERE id = p_user_id;
  
  -- Check if push is enabled
  IF NOT COALESCE(v_push_enabled, false) THEN
    RETURN false;
  END IF;
  
  -- Check 18h cooldown
  IF v_last_push_at IS NOT NULL AND 
     v_last_push_at > now() - interval '18 hours' THEN
    RETURN false;
  END IF;
  
  -- Count pushes today (max 1)
  SELECT COUNT(*) INTO v_pushes_today
  FROM public.notification_log
  WHERE user_id = p_user_id
    AND delivered = true
    AND delivered_at > date_trunc('day', now());
  
  IF v_pushes_today >= 1 THEN
    RETURN false;
  END IF;
  
  -- Count pushes this week (max 3)
  SELECT COUNT(*) INTO v_pushes_this_week
  FROM public.notification_log
  WHERE user_id = p_user_id
    AND delivered = true
    AND delivered_at > now() - interval '7 days';
  
  IF v_pushes_this_week >= 3 THEN
    RETURN false;
  END IF;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================
-- DONE
-- ============================================
SELECT 'Migration completed successfully!' as status;
