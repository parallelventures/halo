-- ============================================
-- Add Creator Mode Entitlement to User
-- User ID: 930a026f-baa0-4623-9478-adbd6c073fa1
-- ============================================

-- Enable creator mode and set renewal date (7 days from now)
UPDATE public.entitlements
SET 
  creator_mode_active = true,
  creator_mode_renewal_at = NOW() + INTERVAL '7 days',
  creator_mode_daily_used = 0,
  creator_mode_last_reset_date = CURRENT_DATE,
  quality_tier = 'creator_mode',
  watermark_disabled = true,
  updated_at = NOW()
WHERE user_id = '930a026f-baa0-4623-9478-adbd6c073fa1';

-- If the user doesn't have an entitlements record, create one
INSERT INTO public.entitlements (
  user_id,
  creator_mode_active,
  creator_mode_renewal_at,
  creator_mode_daily_used,
  creator_mode_last_reset_date,
  quality_tier,
  watermark_disabled,
  looks_balance,
  updated_at
)
VALUES (
  '930a026f-baa0-4623-9478-adbd6c073fa1',
  true,
  NOW() + INTERVAL '7 days',
  0,
  CURRENT_DATE,
  'premium',
  true,
  0,
  NOW()
)
ON CONFLICT (user_id) DO UPDATE SET
  creator_mode_active = true,
  creator_mode_renewal_at = NOW() + INTERVAL '7 days',
  creator_mode_daily_used = 0,
  creator_mode_last_reset_date = CURRENT_DATE,
  quality_tier = 'creator_mode',
  watermark_disabled = true,
  updated_at = NOW();

-- Update the user's segment to POWER (since creator mode users are POWER users)
UPDATE public.profiles
SET 
  primary_segment = 'POWER',
  updated_at = NOW()
WHERE id = '930a026f-baa0-4623-9478-adbd6c073fa1';

-- Verify the changes
SELECT 
  e.user_id,
  e.creator_mode_active,
  e.creator_mode_renewal_at,
  e.quality_tier,
  e.watermark_disabled,
  e.looks_balance,
  p.primary_segment
FROM public.entitlements e
LEFT JOIN public.profiles p ON e.user_id = p.id
WHERE e.user_id = '930a026f-baa0-4623-9478-adbd6c073fa1';
