// Supabase Edge Function: sync-entitlements
// Allows authenticated users to safely sync their subscription status
// This is critical for "Restore Purchases" and self-healing
// 🚨 FIXED: Now verifies with RevenueCat server-side + ensures row exists

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// RevenueCat API for server-side verification
const REVENUECAT_API_KEY = Deno.env.get('REVENUECAT_API_KEY') || ''

serve(async (req) => {
    // 1. Handle CORS
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // 2. Auth Check (Must be logged in user)
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            return new Response(JSON.stringify({ error: 'Missing Auth Header' }), { status: 401, headers: corsHeaders })
        }

        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: authHeader } } }
        )

        const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
        if (userError || !user) {
            return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: corsHeaders })
        }

        // 3. Parse Body - client sends what it thinks the state is
        const { active: clientActive } = await req.json()

        console.log(`🔄 Syncing entitlement for user ${user.id}: client says active=${clientActive}`)

        // 4. 🚨 CRITICAL: Verify with RevenueCat server-side (source of truth)
        let serverActive = clientActive  // Default to client value

        if (REVENUECAT_API_KEY) {
            try {
                console.log(`🔍 Verifying with RevenueCat API...`)
                const rcResponse = await fetch(
                    `https://api.revenuecat.com/v1/subscribers/${user.id}`,
                    {
                        headers: {
                            'Authorization': `Bearer ${REVENUECAT_API_KEY}`,
                            'Content-Type': 'application/json'
                        }
                    }
                )

                if (rcResponse.ok) {
                    const rcData = await rcResponse.json()
                    const subscriber = rcData.subscriber
                    const now = new Date()

                    // Check 1: Entitlements (preferred)
                    let hasEntitlement = false
                    if (subscriber?.entitlements?.creator?.expires_date) {
                        hasEntitlement = new Date(subscriber.entitlements.creator.expires_date) > now
                    }
                    if (subscriber?.entitlements?.atelier?.expires_date) {
                        hasEntitlement = hasEntitlement || new Date(subscriber.entitlements.atelier.expires_date) > now
                    }

                    // Check 2: Active subscriptions (fallback if entitlement mapping is broken)
                    let hasActiveSub = false
                    if (subscriber?.subscriptions) {
                        for (const [subId, sub] of Object.entries(subscriber.subscriptions)) {
                            const subData = sub as any
                            if (subData.expires_date && new Date(subData.expires_date) > now) {
                                hasActiveSub = true
                                console.log(`📦 Active subscription: ${subId}, expires: ${subData.expires_date}`)
                                break
                            }
                        }
                    }

                    serverActive = hasEntitlement || hasActiveSub
                    console.log(`📦 RevenueCat: entitlement=${hasEntitlement}, activeSub=${hasActiveSub}, final=${serverActive}`)
                } else if (rcResponse.status === 404) {
                    console.log(`ℹ️ User not found in RevenueCat (new user)`)
                    serverActive = false
                } else {
                    console.log(`⚠️ RevenueCat API error: ${rcResponse.status}`)
                }
            } catch (rcError) {
                console.log(`⚠️ RevenueCat verification failed, using client value: ${rcError}`)
            }
        } else {
            console.log(`⚠️ REVENUECAT_API_KEY not configured, trusting client value`)
        }

        const finalActive = serverActive

        // 5. Admin Update (Bypass RLS) - PROTECT LOOKS BALANCE
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // Try UPDATE first to preserve existing data (like looks_balance)
        const { data: updated, error: updateError } = await supabaseAdmin
            .from('entitlements')
            .update({
                creator_mode_active: finalActive,
                quality_tier: finalActive ? 'creator_mode' : 'standard',
                watermark_disabled: finalActive,
                updated_at: new Date().toISOString()
            })
            .eq('user_id', user.id)
            .select()

        if (updateError) {
            console.error('❌ Update failed:', updateError)
            throw updateError
        }

        // If no row existed, INSERT a new one
        if (!updated || updated.length === 0) {
            console.log('⚠️ No existing entitlement found, creating new record...')
            const { error: insertError } = await supabaseAdmin
                .from('entitlements')
                .insert({
                    user_id: user.id,
                    creator_mode_active: finalActive,
                    looks_balance: 0,
                    quality_tier: finalActive ? 'creator_mode' : 'standard',
                    watermark_disabled: finalActive,
                    updated_at: new Date().toISOString()
                })

            if (insertError) {
                // Handle race condition
                if (insertError.code === '23505') {
                    console.log('⚠️ Race condition - retrying update')
                    await supabaseAdmin
                        .from('entitlements')
                        .update({
                            creator_mode_active: finalActive,
                            quality_tier: finalActive ? 'creator_mode' : 'standard',
                            watermark_disabled: finalActive,
                            updated_at: new Date().toISOString()
                        })
                        .eq('user_id', user.id)
                } else {
                    throw insertError
                }
            }
        }

        console.log(`✅ Sync successful: creator_mode_active=${finalActive}`)

        return new Response(
            JSON.stringify({
                success: true,
                creator_mode_active: finalActive,
                verified_with_revenuecat: !!REVENUECAT_API_KEY
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error('💥 Sync error:', error)
        return new Response(
            JSON.stringify({ error: String(error) }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
