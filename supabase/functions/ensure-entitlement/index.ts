// Supabase Edge Function: ensure-entitlement
// Ensures authenticated user has an entitlement row in the database
// This is CRITICAL for users who pay before signing in
// Called after auth to guarantee entitlement exists for generation checks

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// RevenueCat API for server-side verification
const REVENUECAT_API_KEY = Deno.env.get('REVENUECAT_API_KEY') || ''

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // 1. Authenticate user
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            return new Response(
                JSON.stringify({ error: 'Missing auth header' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: authHeader } } }
        )

        const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
        if (userError || !user) {
            return new Response(
                JSON.stringify({ error: 'Unauthorized' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        console.log(`🔧 Ensuring entitlement exists for user: ${user.id}`)

        // 2. Setup admin client
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 3. Check if entitlement row exists
        const { data: existing, error: checkError } = await supabaseAdmin
            .from('entitlements')
            .select('user_id, creator_mode_active, looks_balance')
            .eq('user_id', user.id)
            .single()

        if (existing) {
            console.log(`✅ Entitlement already exists: creator_mode=${existing.creator_mode_active}, balance=${existing.looks_balance}`)
            return new Response(
                JSON.stringify({
                    success: true,
                    action: 'exists',
                    creator_mode_active: existing.creator_mode_active,
                    looks_balance: existing.looks_balance
                }),
                { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // 4. Row doesn't exist - check RevenueCat for subscription status AND purchased looks
        let creatorModeActive = false
        let recoveredLooksBalance = 0

        if (REVENUECAT_API_KEY) {
            try {
                console.log(`🔍 Checking RevenueCat for user ${user.id}...`)
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
                    // Legacy: "Studio" entitlement from older RC configuration
                    if (subscriber?.entitlements?.Studio?.expires_date) {
                        hasEntitlement = hasEntitlement || new Date(subscriber.entitlements.Studio.expires_date) > now
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

                    creatorModeActive = hasEntitlement || hasActiveSub
                    console.log(`📦 RevenueCat: entitlement=${hasEntitlement}, activeSub=${hasActiveSub}, final=${creatorModeActive}`)

                    // 🚨 CRITICAL FIX: Also check for non-subscription purchases (looks packs)
                    // These might have been purchased before auth and never synced
                    if (subscriber?.non_subscriptions) {
                        let totalLooksPurchased = 0
                        for (const [productId, purchases] of Object.entries(subscriber.non_subscriptions)) {
                            const purchaseArray = purchases as any[]
                            for (const _purchase of purchaseArray) {
                                if (productId.includes('10looks')) totalLooksPurchased += 10
                                else if (productId.includes('30looks')) totalLooksPurchased += 30
                                else if (productId.includes('100looks')) totalLooksPurchased += 100
                            }
                        }

                        if (totalLooksPurchased > 0) {
                            console.log(`💎 Found ${totalLooksPurchased} looks purchased in RevenueCat`)

                            // Estimate used looks from generations count
                            const supabaseAdmin2 = createClient(
                                Deno.env.get('SUPABASE_URL') ?? '',
                                Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
                            )
                            const { count: totalGens } = await supabaseAdmin2
                                .from('generations')
                                .select('*', { count: 'exact', head: true })
                                .eq('user_id', user.id)

                            const estimatedUsed = Math.min(totalGens ?? 0, totalLooksPurchased)
                            recoveredLooksBalance = Math.max(0, totalLooksPurchased - estimatedUsed)
                            console.log(`💎 Recovering ${recoveredLooksBalance} looks (purchased: ${totalLooksPurchased}, used: ~${estimatedUsed})`)
                        }
                    }
                } else {
                    console.log(`⚠️ RevenueCat lookup failed: ${rcResponse.status}`)
                }
            } catch (rcError) {
                console.log(`⚠️ RevenueCat check failed: ${rcError}`)
            }
        } else {
            console.log(`⚠️ REVENUECAT_API_KEY not set, skipping server-side verification`)
        }

        // 5. Create entitlement row with recovered data
        console.log(`➕ Creating entitlement row: creator_mode_active=${creatorModeActive}, looks_balance=${recoveredLooksBalance}`)

        const { error: insertError } = await supabaseAdmin
            .from('entitlements')
            .insert({
                user_id: user.id,
                creator_mode_active: creatorModeActive,
                looks_balance: recoveredLooksBalance,
                quality_tier: creatorModeActive ? 'creator_mode' : 'standard',
                watermark_disabled: creatorModeActive,
                updated_at: new Date().toISOString()
            })

        if (insertError) {
            // Could be race condition - row was just created. Check again.
            if (insertError.code === '23505') { // unique_violation
                console.log(`⚠️ Race condition - row was just created by another process`)

                // 🚨 FIX: If race condition but we have recovered looks, UPDATE the existing row
                if (recoveredLooksBalance > 0 || creatorModeActive) {
                    await supabaseAdmin
                        .from('entitlements')
                        .update({
                            creator_mode_active: creatorModeActive,
                            looks_balance: recoveredLooksBalance,
                            quality_tier: creatorModeActive ? 'creator_mode' : 'standard',
                            watermark_disabled: creatorModeActive,
                            updated_at: new Date().toISOString()
                        })
                        .eq('user_id', user.id)
                }

                // Sync to user_credits too
                if (recoveredLooksBalance > 0) {
                    await supabaseAdmin.rpc('add_credits', {
                        p_user_id: user.id,
                        p_amount: recoveredLooksBalance
                    })
                }

                return new Response(
                    JSON.stringify({ success: true, action: 'race_condition_healed' }),
                    { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }
            throw insertError
        }

        // 🚨 CRITICAL: Also sync recovered looks to user_credits table
        // The client reads from user_credits via get-credits/spend-credit RPCs
        if (recoveredLooksBalance > 0) {
            console.log(`💎 Syncing ${recoveredLooksBalance} recovered looks to user_credits table`)
            const { error: creditsError } = await supabaseAdmin.rpc('add_credits', {
                p_user_id: user.id,
                p_amount: recoveredLooksBalance
            })
            if (creditsError) {
                console.error(`⚠️ Failed to sync to user_credits: ${creditsError.message}`)
            }
        }

        console.log(`✅ Entitlement row created successfully`)

        return new Response(
            JSON.stringify({
                success: true,
                action: 'created',
                creator_mode_active: creatorModeActive
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error('💥 ensure-entitlement error:', error)
        return new Response(
            JSON.stringify({ error: String(error) }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
