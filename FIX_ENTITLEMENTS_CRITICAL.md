# 🚨 CRITICAL FIX: Entitlements Not Working After Payment

**Date:** 2026-02-08
**Status:** FIXED

## The Problem

When a user pays for a subscription, they couldn't generate hairstyles because their `creator_mode_active` flag was `false` in the database, even though RevenueCat showed an active subscription.

## Root Cause Analysis

### Issue #1 - The Upsert Bug 🐛

In `AuthService.swift`, the `ensureProfileAndEntitlements()` function was doing:

```swift
let entitlementsData: [String: Any] = [
    "user_id": userId,
    "looks_balance": 0,
    "creator_mode_active": false,  // ❌ HARDCODED TO FALSE!
    //...
]

try await supabase
    .from("entitlements")
    .upsert(entitlementsData)  // ❌ OVERWRITES existing data!
    .execute()
```

**Problem:** This was called AFTER `SubscriptionManager.login()`, which could set the correct subscription status. The upsert was **OVERWRITING** `creator_mode_active` back to `false`!

### Issue #2 - Conditional Sync

In `SubscriptionManager.login()`:

```swift
if isSubscribed {
    await syncCreatorModeToSupabase(active: true)
}
```

**Problem:** If `isSubscribed` was `false` due to a race condition or restore failure, the sync was skipped entirely.

## The Fix

### Fix #1 - Use Edge Function for Entitlements

Changed `ensureProfileAndEntitlements()` to call the `ensure-entitlement` Edge Function instead of doing a client-side upsert. The Edge Function:
1. Checks if an entitlement row already exists
2. If not, verifies with RevenueCat API server-side
3. Creates the row with the correct `creator_mode_active` value

```swift
// NEW: Call Edge Function that properly checks RevenueCat
let _ = try await supabase.functions
    .invoke("ensure-entitlement", body: [:] as [String: String])
```

### Fix #2 - Always Sync After Login

Changed `SubscriptionManager.login()` to ALWAYS sync entitlements after restore:

```swift
// OLD:
if isSubscribed {
    await syncCreatorModeToSupabase(active: true)
}

// NEW: Always sync - Edge Function verifies with RevenueCat anyway
await syncCreatorModeToSupabase(active: isSubscribed)
```

## Files Changed

1. **`Eclat/Core/Services/AuthService.swift`**
   - `ensureProfileAndEntitlements()` now uses Edge Function

2. **`Eclat/Core/Services/SubscriptionManager.swift`**
   - `login()` always syncs entitlements after restore

## Flow After Fix

```
User signs in (Apple/Google)
    ↓
await SubscriptionManager.login(userId)
    ↓
    ├─ Purchases.shared.logIn(userId)  → Aliases the anonymous ID
    ├─ Purchases.shared.restorePurchases()  → Recovers subscriptions
    └─ syncCreatorModeToSupabase()  → ALWAYS called now
         ↓
         Edge Function: sync-entitlements
             ↓
             Verifies with RevenueCat API server-side
             ↓
             Updates Supabase with correct creator_mode_active
    ↓
await ensureProfileAndEntitlements(userId)
    ↓
    Edge Function: ensure-entitlement
        ↓
        If row exists → Returns existing (doesn't overwrite)
        If not → Checks RevenueCat → Creates with correct value
    ↓
User navigates to Home → Can generate ✅
```

## Diagnostic Tools

Created `scripts/diagnose_entitlement.sh` to check a user's entitlement status:

```bash
./scripts/diagnose_entitlement.sh <user_id>
```

## Quick Fix for Affected Users

Run this SQL in Supabase SQL Editor:

```sql
INSERT INTO public.entitlements (user_id, creator_mode_active, quality_tier, watermark_disabled, looks_balance, updated_at)
VALUES ('<USER_ID>', true, 'creator_mode', true, 0, NOW())
ON CONFLICT (user_id) DO UPDATE SET
    creator_mode_active = true,
    quality_tier = 'creator_mode',
    watermark_disabled = true,
    updated_at = NOW();
```

## Verification

1. Build and run the app with the new code
2. Create a new test account
3. Purchase a subscription
4. Verify `creator_mode_active` is `true` in Supabase
5. Verify user can generate hairstyles

## Prevention

- Edge Functions should be the source of truth for subscription verification
- Client-side code should never hardcode `creator_mode_active` values
- Always sync after any authentication event
- Always sync after any purchase event
