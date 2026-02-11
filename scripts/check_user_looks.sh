#!/bin/bash

# Script pour vérifier le solde de looks d'un utilisateur dans Supabase
# Usage: ./check_user_looks.sh <user_id>

# Configuration Supabase
SUPABASE_URL="https://noqpxmaipkhsresxyupl.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5vcXB4bWFpcGtoc3Jlc3h5dXBsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0NjI4MjIsImV4cCI6MjA4MzAzODgyMn0.AgHtUmBBBfB8992P2t6RQ1MtkUvuDm3XaRqxqVwlzk8"

# User ID à vérifier (paramètre ou valeur par défaut)
USER_ID="${1:-a15b67db-dfca-4eda-b3aa-53f7111026b9}"

echo "🔍 Checking looks balance for user: $USER_ID"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Requête vers la table entitlements
RESPONSE=$(curl -s \
  "${SUPABASE_URL}/rest/v1/entitlements?user_id=eq.${USER_ID}&select=looks_balance,user_id,updated_at" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json")

echo "📊 Response:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

# Extraire le solde
BALANCE=$(echo "$RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data[0]['looks_balance'] if data else 'No entitlement found')" 2>/dev/null)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Looks Balance: $BALANCE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
