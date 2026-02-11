#!/bin/bash

# Script pour ajouter des looks à un utilisateur via UPSERT
# Usage: ./add_user_looks.sh <user_id> <amount>

# Configuration Supabase
SUPABASE_URL="https://noqpxmaipkhsresxyupl.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5vcXB4bWFpcGtoc3Jlc3h5dXBsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0NjI4MjIsImV4cCI6MjA4MzAzODgyMn0.AgHtUmBBBfB8992P2t6RQ1MtkUvuDm3XaRqxqVwlzk8"

USER_ID="${1:-a15b67db-dfca-4eda-b3aa-53f7111026b9}"
AMOUNT="${2:-5}"

echo "➕ Adding $AMOUNT looks to user: $USER_ID"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Try to UPSERT into entitlements table
RESPONSE=$(curl -s -X POST \
  "${SUPABASE_URL}/rest/v1/entitlements" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=merge-duplicates,return=representation" \
  -d "{
    \"user_id\": \"${USER_ID}\",
    \"looks_balance\": ${AMOUNT}
  }")

echo "📊 Response:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

# Check if it worked
if echo "$RESPONSE" | grep -q "looks_balance"; then
    echo ""
    echo "✅ SUCCESS! User now has looks."
else
    echo ""
    echo "⚠️  The anon key might not have INSERT permissions."
    echo ""
    echo "👉 MANUAL SQL (run in Supabase Dashboard > SQL Editor):"
    echo ""
    echo "INSERT INTO entitlements (user_id, looks_balance)"
    echo "VALUES ('${USER_ID}', ${AMOUNT})"
    echo "ON CONFLICT (user_id)"
    echo "DO UPDATE SET looks_balance = entitlements.looks_balance + ${AMOUNT};"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
