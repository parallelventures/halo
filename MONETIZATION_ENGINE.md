# Eclat Monetization Engine v2.0

## Architecture Overview

This document describes the top-tier monetization system implemented for Eclat, featuring server-driven offer decisions, segment-based copy, cooldowns, and fair-use enforcement.

---

## Files Created/Modified

### 1. Supabase Migration
**File:** `supabase/migrations/20260120_monetization_engine.sql`

Tables created:
- `profiles` - User profiles with segmentation tags
- `entitlements` - Wallet (looks_balance) + Creator Mode status
- `monetization_events` - Purchase history (source of truth)
- `offer_impressions` - For cooldown tracking
- `generations` - Generation history with save/share tracking
- `styles` - Styles catalog

Key functions:
- `compute_primary_segment(user_id)` - Computes TOURIST/SAMPLER/EXPLORER/BUYER/POWER
- `check_offer_cooldown(user_id, offer_key)` - 24h same offer, 4h any offer
- `count_daily_impressions(user_id)` - Max 2/day, 5/week

### 2. Edge Functions
**Files:** 
- `supabase/functions/decide-offer/index.ts` - Server-side decision engine
- `supabase/functions/record-impression/index.ts` - Records offer impressions

The `decide-offer` function:
- Checks user segment, cooldowns, and impression limits
- Returns the appropriate offer (entry, packs, or creator_mode)
- Includes segment-specific copy variants

### 3. Swift MonetizationEngine
**File:** `Eclat/Core/Services/MonetizationEngine.swift`

A service that:
- Calls server-side decision engine
- Falls back to local logic if server unavailable
- Tracks local impressions for cooldowns
- Provides segment-based copy variants

### 4. SegmentedPaywallView
**File:** `Eclat/Features/Paywall/SegmentedPaywallView.swift`

A dynamic paywall that renders:
- **Entry Paywall** ($2.99 one-time) for tourists
- **Packs Paywall** (10/30/100 looks) for samplers
- **Creator Mode Paywall** ($12.99/week) for explorers/buyers

### 5. AppState Updates
**File:** `Eclat/App/AppState.swift`

Added:
- `currentOfferDecision: OfferDecision?`
- `showSegmentedPaywall: Bool`
- `showSmartPaywall(for: MonetizationEvent)` - Server-driven paywall trigger

### 6. RootView Updates
**File:** `Eclat/App/RootView.swift`

Added new fullScreenCover for `SegmentedPaywallView`.

---

## User Segments

| Segment | Criteria | Goal |
|---------|----------|------|
| TOURIST | 0 purchases, ≤2 looks, ≤1 session | First paid step |
| SAMPLER | Bought entry OR 3-7 looks used | Exploration loop |
| EXPLORER | ≥8 looks OR saves/shares OR 2+ sessions | Recurring revenue |
| BUYER | ≥1 pack purchase | Convert to weekly |
| POWER | Weekly sub OR (≥30 looks + repeat buyer) | Retention |

---

## Offer Flow by Segment

### TOURIST
- **try_generate** → Entry Paywall ($2.99)
- **out_of_looks** → Entry first, then Packs

### SAMPLER
- **out_of_looks** → Creator Mode (soft), Packs as secondary
- **save/share** → Creator Mode (pill, subtle)

### EXPLORER/BUYER
- **out_of_looks** → Creator Mode (primary), Packs as secondary
- **attempt_second_pack** → Creator Mode intercept

### POWER
- Minimal paywalls, prioritize experience

---

## Cooldowns & Limits

| Rule | Value |
|------|-------|
| Same offer cooldown | 24 hours |
| Any offer cooldown | 4 hours |
| Max daily impressions | 2 |
| Max weekly impressions | 5 |

---

## Fair-Use Caps (Creator Mode)

| Limit | Value |
|-------|-------|
| Studio-grade generations/day | 8 (recommended) |
| Hard cap (any user) | 120/day |

---

## Copy Variants

Each segment gets tailored copy:

### Entry (TOURIST)
- Title: "Unlock your first looks"
- Subtitle: "Preview your next hairstyle on you — instantly."
- CTA: "Unlock for $2.99"
- Footnote: "One-time purchase. No subscription."

### Creator Mode (EXPLORER)
- Title: "Creator Mode"
- Subtitle: "You're exploring deeply. Don't count looks."
- CTA: "Enter Creator Mode — $12.99/week"
- Secondary: "Buy looks instead"

---

## Deployment Steps

1. **Run Supabase Migration:**
   ```bash
   # In Supabase SQL Editor, run:
   supabase/migrations/20260120_monetization_engine.sql
   ```

2. **Deploy Edge Functions:**
   ```bash
   supabase functions deploy decide-offer
   supabase functions deploy record-impression
   ```

3. **Add to Xcode Project:**
   - Add `MonetizationEngine.swift` to Core/Services
   - Add `SegmentedPaywallView.swift` to Features/Paywall

4. **Test:**
   - Verify segment computation
   - Test cooldown logic
   - Verify RevenueCat webhook → Supabase flow

---

## Usage Examples

### Show smart paywall on out of looks:
```swift
appState.showSmartPaywall(for: .outOfLooks)
```

### Show paywall after save/share (soft upsell):
```swift
appState.showSmartPaywall(for: .saveResult)
```

### Check if user has entry access:
```swift
if subscriptionManager.hasEntryAccess {
    // Show credits paywall
} else {
    // Show entry paywall
}
```

---

## RevenueCat Webhook Integration

Configure RevenueCat webhook to call a Supabase Edge Function that:
1. Updates `entitlements` table
2. Logs to `monetization_events`
3. Recomputes `primary_segment`

This ensures the server is the source of truth for entitlements.

---

## Push Notification System

### Architecture

The push notification system is **segment-based** with strict frequency controls:

| Rule | Value |
|------|-------|
| Max pushes/day | 1 |
| Max pushes/week | 3 |
| Cooldown between pushes | 18 hours |
| Quiet hours | 22:00 - 09:00 local |

### Notification Keys by Segment

**TOURIST:**
- `tourist_t6` - 6h after install
- `tourist_t24` - 24h after install  
- `tourist_t48` - 48h after install

**SAMPLER:**
- `sampler_first_result` - 3h after first result
- `sampler_next_day` - Next day 19:00
- `sampler_t48_purchase` - 48h after entry purchase

**EXPLORER:**
- `explorer_evening` - 20:00 same day
- `explorer_next_day` - 18:00 next day
- `explorer_weekly` - 1x per week

**BUYER:**
- `buyer_post_purchase` - After pack purchase
- `buyer_t24_purchase` - 24h after pack
- `buyer_low_looks` - When balance hits 2

**CREATOR MODE:**
- `creator_day1` - Day 1 of subscription
- `creator_day5` - Day 5 pre-renewal

**CHURN:**
- `churn_48h` - 48h inactive
- `churn_7d` - 7d inactive

### Usage

```swift
// Request permission after win moment (save/share/purchase)
NotificationManager.shared.requestPermission(afterWinMoment: true)

// Schedule notifications on app open
NotificationManager.shared.scheduleSmartNotifications()

// After first result
NotificationManager.shared.scheduleAfterFirstResult()

// After purchase
NotificationManager.shared.scheduleAfterPurchase(isCreatorMode: false)
```

### Premium Copy Rules

- No emojis
- No "limited time" or urgency
- No "BUY NOW"
- Use "unlock/enter/explore" language
- Invite, don't pressure

