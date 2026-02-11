# FIX: Entitlements Not Syncing After Purchase

## Root Cause
When a user purchases a subscription **before signing in**:
1. RevenueCat records the purchase with `$RCAnonymousID:abc123`
2. The webhook can't find a Supabase UUID in aliases → **SKIPS the database update**
3. User signs in later → Supabase user exists but **no entitlement row**
4. User can't generate even though they paid

## Solution Implemented

### 1. `SubscriptionManager.syncEntitlementsAfterAuth()` (Swift)
Now does a **comprehensive sync** after auth:
- Always restores purchases from RevenueCat first
- Always syncs to Supabase (regardless of local subscription state)
- Calls `ensure-entitlement` to guarantee row exists

### 2. New Edge Function: `ensure-entitlement`
- Called after authentication
- Checks if entitlement row exists
- If not, checks RevenueCat API server-side for subscription status
- Creates entitlement row with correct `creator_mode_active` flag

### 3. Updated Edge Function: `sync-entitlements`
- Now verifies with RevenueCat API server-side (source of truth)
- Creates entitlement row if missing
- Sets `quality_tier` and `watermark_disabled` based on subscription

## Deployment Steps

### 1. Set RevenueCat API Key in Supabase
```bash
# Get your RevenueCat Secret API Key from:
# https://app.revenuecat.com/projects/YOUR_PROJECT/api-keys

supabase secrets set REVENUECAT_API_KEY=sk_YOUR_REVENUECAT_SECRET_KEY
```

### 2. Deploy Edge Functions
```bash
cd /Users/imranhassani/.gemini/antigravity/scratch/Halo

# Deploy the new function
supabase functions deploy ensure-entitlement

# Deploy the updated function
supabase functions deploy sync-entitlements
```

### 3. Fix Existing User (Manual)
Run this SQL in Supabase SQL Editor for user `930a026f-baa0-4623-9478-adbd6c073fa1`:
```sql
INSERT INTO public.entitlements (
  user_id,
  creator_mode_active,
  creator_mode_renewal_at,
  quality_tier,
  watermark_disabled,
  looks_balance,
  updated_at
)
VALUES (
  '930a026f-baa0-4623-9478-adbd6c073fa1',
  true,
  NOW() + INTERVAL '7 days',
  'creator_mode',
  true,
  0,
  NOW()
)
ON CONFLICT (user_id) DO UPDATE SET
  creator_mode_active = true,
  creator_mode_renewal_at = NOW() + INTERVAL '7 days',
  quality_tier = 'creator_mode',
  watermark_disabled = true,
  updated_at = NOW();
```

## Files Changed
- `Eclat/Core/Services/SubscriptionManager.swift` - Enhanced sync flow
- `Eclat/Features/Auth/AuthView.swift` - Simplified sync call
- `supabase/functions/ensure-entitlement/index.ts` - NEW
- `supabase/functions/sync-entitlements/index.ts` - UPDATED
