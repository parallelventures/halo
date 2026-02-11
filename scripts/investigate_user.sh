#!/bin/bash

# Script pour investiguer un utilisateur - looks, générations, transactions
# Usage: ./investigate_user.sh <user_id>

# Configuration Supabase
SUPABASE_URL="https://noqpxmaipkhsresxyupl.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5vcXB4bWFpcGtoc3Jlc3h5dXBsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0NjI4MjIsImV4cCI6MjA4MzAzODgyMn0.AgHtUmBBBfB8992P2t6RQ1MtkUvuDm3XaRqxqVwlzk8"

USER_ID="${1:-a15b67db-dfca-4eda-b3aa-53f7111026b9}"

echo "🔍 INVESTIGATION COMPLÈTE - User: $USER_ID"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Check entitlements (looks balance)
echo "📊 1. ENTITLEMENTS (Looks Balance)"
echo "-----------------------------------"
curl -s \
  "${SUPABASE_URL}/rest/v1/entitlements?user_id=eq.${USER_ID}&select=*" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" | python3 -m json.tool 2>/dev/null || echo "No data or error"
echo ""

# 2. Check user_credits (alternative table)
echo "� 2. USER CREDITS"
echo "-----------------------------------"
curl -s \
  "${SUPABASE_URL}/rest/v1/user_credits?user_id=eq.${USER_ID}&select=*" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" | python3 -m json.tool 2>/dev/null || echo "No data or error"
echo ""

# 3. Check generations (all columns)
echo "�️  3. GENERATIONS (Images créées)"
echo "-----------------------------------"
curl -s \
  "${SUPABASE_URL}/rest/v1/generations?user_id=eq.${USER_ID}&select=*&order=created_at.desc&limit=10" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" | python3 -m json.tool 2>/dev/null || echo "No data or error"
echo ""

# 4. Check monetization_events
echo "� 4. MONETIZATION EVENTS"
echo "-----------------------------------"
curl -s \
  "${SUPABASE_URL}/rest/v1/monetization_events?user_id=eq.${USER_ID}&select=*&order=created_at.desc&limit=5" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" | python3 -m json.tool 2>/dev/null || echo "No data or error"
echo ""

# 5. Check profiles
echo "👤 5. PROFILES"
echo "-----------------------------------"
curl -s \
  "${SUPABASE_URL}/rest/v1/profiles?id=eq.${USER_ID}&select=*" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" | python3 -m json.tool 2>/dev/null || echo "No data or error"
echo ""

# 6. Check onboarding_data
echo "� 6. ONBOARDING DATA"
echo "-----------------------------------"
curl -s \
  "${SUPABASE_URL}/rest/v1/onboarding_data?user_id=eq.${USER_ID}&select=*" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" | python3 -m json.tool 2>/dev/null || echo "No data or error"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Investigation terminée"
