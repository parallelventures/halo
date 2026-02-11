#!/bin/bash
# diagnose_entitlement.sh - Diagnose entitlement issues for a user
# Usage: ./diagnose_entitlement.sh <user_id>

set -e

USER_ID="${1:-}"

if [ -z "$USER_ID" ]; then
    echo "❌ Usage: $0 <user_id>"
    echo "   Example: $0 ca2a6f2a-20d1-44b1-ad03-02f429488e06"
    exit 1
fi

# Load Supabase config
SUPABASE_URL="${SUPABASE_URL:-https://noqpxmaipkhsresxyupl.supabase.co}"
SUPABASE_SERVICE_KEY="${SUPABASE_SERVICE_KEY:-}"

# Try to load from .env if not set
if [ -z "$SUPABASE_SERVICE_KEY" ]; then
    if [ -f ".env.local" ]; then
        source .env.local 2>/dev/null || true
    fi
    if [ -f ".env" ]; then
        source .env 2>/dev/null || true
    fi
fi

if [ -z "$SUPABASE_SERVICE_KEY" ]; then
    echo "⚠️  SUPABASE_SERVICE_KEY not set. Using anon key (limited access)."
    SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5vcXB4bWFpcGtoc3Jlc3h5dXBsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQ2MTU2MjcsImV4cCI6MjA1MDE5MTYyN30.Ss0vEuHQ25E18Fv5cAwKuqXo-vTPl2fQIvCTOPgm9hw"
else
    SUPABASE_KEY="$SUPABASE_SERVICE_KEY"
fi

echo ""
echo "🔍 DIAGNOSING ENTITLEMENTS FOR USER: $USER_ID"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Check profiles table
echo ""
echo "📋 1. PROFILE:"
PROFILE=$(curl -s "${SUPABASE_URL}/rest/v1/profiles?id=eq.${USER_ID}&select=*" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}")

if [ "$PROFILE" = "[]" ]; then
    echo "   ❌ NO PROFILE FOUND"
else
    echo "$PROFILE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data:
    p = data[0]
    print(f\"   ✅ Email: {p.get('email', 'N/A')}\")
    print(f\"   ✅ Name: {p.get('full_name', 'N/A')}\")
    print(f\"   ✅ Updated: {p.get('updated_at', 'N/A')}\")
" 2>/dev/null || echo "   Error parsing profile"
fi

# 2. Check entitlements table
echo ""
echo "🎫 2. ENTITLEMENTS:"
ENTITLEMENTS=$(curl -s "${SUPABASE_URL}/rest/v1/entitlements?user_id=eq.${USER_ID}&select=*" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}")

if [ "$ENTITLEMENTS" = "[]" ]; then
    echo "   ❌ NO ENTITLEMENT ROW FOUND (This is the problem!)"
    echo "   🔧 Fix: Run sync-entitlements Edge Function for this user"
else
    echo "$ENTITLEMENTS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data:
    e = data[0]
    creator = e.get('creator_mode_active', False)
    balance = e.get('looks_balance', 0)
    tier = e.get('quality_tier', 'N/A')
    updated = e.get('updated_at', 'N/A')
    
    status = '✅' if creator else '❌'
    print(f\"   {status} creator_mode_active: {creator}\")
    print(f\"   💎 looks_balance: {balance}\")
    print(f\"   🏷️  quality_tier: {tier}\")
    print(f\"   📅 updated_at: {updated}\")
" 2>/dev/null || echo "   Error parsing entitlements"
fi

# 3. Check monetization events
echo ""
echo "💰 3. RECENT MONETIZATION EVENTS:"
EVENTS=$(curl -s "${SUPABASE_URL}/rest/v1/monetization_events?user_id=eq.${USER_ID}&select=*&order=created_at.desc&limit=5" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}")

if [ "$EVENTS" = "[]" ]; then
    echo "   ℹ️  No monetization events found"
else
    echo "$EVENTS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for e in data:
    event_type = e.get('event_type', 'N/A')
    product = e.get('product_id', 'N/A')
    created = e.get('created_at', 'N/A')
    print(f\"   • {event_type} | {product} | {created}\")
" 2>/dev/null || echo "   Error parsing events"
fi

# 4. Check generations
echo ""
echo "🎨 4. RECENT GENERATIONS (last 5):"
GENS=$(curl -s "${SUPABASE_URL}/rest/v1/generations?user_id=eq.${USER_ID}&select=id,style_name,created_at,status&order=created_at.desc&limit=5" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}")

if [ "$GENS" = "[]" ]; then
    echo "   ℹ️  No generations found"
else
    echo "$GENS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for g in data:
    style = g.get('style_name', 'N/A')
    status = g.get('status', 'N/A')
    created = g.get('created_at', 'N/A')[:16] if g.get('created_at') else 'N/A'
    print(f\"   • {created} | {style} | {status}\")
" 2>/dev/null || echo "   Error parsing generations"
fi

# 5. Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 DIAGNOSIS SUMMARY:"

# Parse entitlements for summary
HAS_CREATOR=$(echo "$ENTITLEMENTS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data and data[0].get('creator_mode_active'):
    print('true')
else:
    print('false')
" 2>/dev/null || echo "false")

HAS_ENTITLEMENT_ROW=$(echo "$ENTITLEMENTS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print('true' if data else 'false')
" 2>/dev/null || echo "false")

if [ "$HAS_ENTITLEMENT_ROW" = "false" ]; then
    echo "   ❌ PROBLEM: No entitlement row exists!"
    echo "   🔧 FIX: User needs to re-authenticate or call ensure-entitlement"
elif [ "$HAS_CREATOR" = "false" ]; then
    echo "   ⚠️  POTENTIAL PROBLEM: creator_mode_active is false"
    echo "   🔧 FIX: If user has paid, run sync-entitlements Edge Function"
else
    echo "   ✅ Entitlements look correct"
fi

echo ""
echo "🔧 QUICK FIX SQL (if user has paid but no entitlement):"
echo ""
echo "INSERT INTO public.entitlements (user_id, creator_mode_active, quality_tier, watermark_disabled, looks_balance, updated_at)"
echo "VALUES ('${USER_ID}', true, 'creator_mode', true, 0, NOW())"
echo "ON CONFLICT (user_id) DO UPDATE SET"
echo "    creator_mode_active = true,"
echo "    quality_tier = 'creator_mode',"
echo "    watermark_disabled = true,"
echo "    updated_at = NOW();"
echo ""
