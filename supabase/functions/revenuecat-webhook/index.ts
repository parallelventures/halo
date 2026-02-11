// Supabase Edge Function: revenuecat-webhook
// Receives webhook events from RevenueCat and updates Supabase entitlements
// This ensures Supabase is always in sync with the source of truth (RevenueCat)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// RevenueCat sends this header to authenticate webhooks
// Set this in RevenueCat Dashboard → Webhooks → Authorization Header
const WEBHOOK_AUTH_HEADER = Deno.env.get('REVENUECAT_WEBHOOK_SECRET') || 'your-webhook-secret'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RevenueCatEvent {
    event: {
        type: string
        app_user_id: string
        original_app_user_id: string
        aliases?: string[]
        product_id?: string
        entitlement_ids?: string[]
        period_type?: string
        purchased_at_ms?: number
        expiration_at_ms?: number
        environment?: string
    }
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        console.log('🔔 RevenueCat webhook received')

        // 1. Verify webhook authentication (optional but recommended)
        const authHeader = req.headers.get('Authorization')
        if (authHeader !== `Bearer ${WEBHOOK_AUTH_HEADER}` && WEBHOOK_AUTH_HEADER !== 'your-webhook-secret') {
            console.error('❌ Invalid webhook authorization')
            return new Response(
                JSON.stringify({ error: 'Unauthorized' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // 2. Parse the webhook payload
        const payload: RevenueCatEvent = await req.json()
        const event = payload.event

        console.log(`📨 Event type: ${event.type}`)
        console.log(`👤 App User ID: ${event.app_user_id}`)
        console.log(`🏷️ Product: ${event.product_id}`)
        console.log(`📦 Entitlements: ${event.entitlement_ids?.join(', ')}`)

        // 3. Setup Supabase Admin client
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

        // 4. Determine the user ID to update
        // RevenueCat uses app_user_id which might be a Supabase UUID or $RCAnonymousID
        let userId = event.app_user_id

        // If it's an anonymous ID, try to find the aliased Supabase user ID
        if (userId.startsWith('$RCAnonymousID')) {
            // Check aliases from the webhook event first
            let supabaseId = event.aliases?.find(id =>
                !id.startsWith('$') && id.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
            )

            // 🚨 FIX: If no alias in webhook, try RevenueCat API for more up-to-date aliases
            if (!supabaseId) {
                const REVENUECAT_API_KEY = Deno.env.get('REVENUECAT_API_KEY') || ''
                if (REVENUECAT_API_KEY) {
                    try {
                        console.log('🔍 No alias in webhook. Checking RevenueCat API for updated aliases...')
                        const rcResponse = await fetch(
                            `https://api.revenuecat.com/v1/subscribers/${event.app_user_id}`,
                            {
                                headers: {
                                    'Authorization': `Bearer ${REVENUECAT_API_KEY}`,
                                    'Content-Type': 'application/json'
                                }
                            }
                        )

                        if (rcResponse.ok) {
                            const rcData = await rcResponse.json()
                            // Check subscriber aliases for a Supabase UUID
                            const subscriberId = rcData.subscriber?.original_app_user_id
                            if (subscriberId && !subscriberId.startsWith('$') &&
                                subscriberId.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)) {
                                supabaseId = subscriberId
                                console.log(`🔗 Found Supabase ID from RC API: ${supabaseId}`)
                            }

                            // Also check other_aliases
                            if (!supabaseId && rcData.subscriber?.other_aliases) {
                                supabaseId = rcData.subscriber.other_aliases.find((id: string) =>
                                    !id.startsWith('$') && id.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
                                )
                                if (supabaseId) {
                                    console.log(`🔗 Found Supabase ID from RC aliases: ${supabaseId}`)
                                }
                            }
                        }
                    } catch (rcError) {
                        console.error('⚠️ RC API alias lookup failed:', rcError)
                    }
                }
            }

            if (supabaseId) {
                userId = supabaseId
                console.log(`🔗 Resolved Supabase ID: ${userId}`)
            } else {
                // 🚨 IMPORTANT: Log the full event for debugging instead of silently skipping
                console.error(`🚨 CRITICAL: Anonymous purchase with NO Supabase ID!`)
                console.error(`   Event type: ${event.type}`)
                console.error(`   Product: ${event.product_id}`)
                console.error(`   RC User ID: ${event.app_user_id}`)
                console.error(`   Aliases: ${JSON.stringify(event.aliases)}`)
                console.error(`   This purchase will be recovered via self-healing on next generation.`)
                return new Response(
                    JSON.stringify({ success: true, message: 'Anonymous purchase logged, will self-heal on auth' }),
                    { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }
        }

        // 5. Determine what to update based on event type
        // 🚨 FIX: Don't rely solely on entitlement_ids — if mapping is broken in RC dashboard,
        // entitlement_ids will be empty even with valid purchases.
        // For subscription events, ALWAYS activate creator mode.
        const hasCreatorEntitlement = event.entitlement_ids?.includes('creator') ?? false
        const hasAnyEntitlement = (event.entitlement_ids?.length ?? 0) > 0
        let creatorModeActive = false
        let eventAction = ''

        switch (event.type) {
            // Subscription started or renewed — ALWAYS activate
            case 'INITIAL_PURCHASE':
            case 'RENEWAL':
            case 'UNCANCELLATION':
            case 'SUBSCRIPTION_EXTENDED':
                creatorModeActive = true  // Any subscription purchase = active
                if (!hasAnyEntitlement) {
                    console.warn(`⚠️ INITIAL_PURCHASE/RENEWAL but no entitlement_ids! Product: ${event.product_id}. Activating anyway.`)
                }
                eventAction = 'activated'
                break

            // Trial events (kept for backwards compatibility, trials removed from product)
            case 'TRIAL_STARTED':
            case 'TRIAL_CONVERTED':
                creatorModeActive = true
                eventAction = event.type === 'TRIAL_STARTED' ? 'trial_started' : 'trial_converted'
                break

            // Subscription expired or cancelled
            case 'EXPIRATION':
            case 'CANCELLATION':
            case 'BILLING_ISSUE':
                creatorModeActive = false
                eventAction = 'deactivated'
                break

            // Non-subscription purchase (credits pack)
            case 'NON_RENEWING_PURCHASE':
                // Handle credits packs
                if (event.product_id?.includes('looks')) {
                    let creditsToAdd = 0
                    if (event.product_id.includes('10looks')) creditsToAdd = 10
                    else if (event.product_id.includes('30looks')) creditsToAdd = 30
                    else if (event.product_id.includes('100looks')) creditsToAdd = 100

                    if (creditsToAdd > 0) {
                        console.log(`💎 Adding ${creditsToAdd} credits to user ${userId}`)

                        // 🚨 CRITICAL: Write to BOTH tables to keep them in sync
                        // Table 1: entitlements.looks_balance (used by decide-offer, ensure-entitlement)
                        const { error: entitlementError } = await supabaseAdmin.rpc('add_looks_balance', {
                            p_user_id: userId,
                            p_amount: creditsToAdd
                        })
                        if (entitlementError) {
                            console.error(`❌ Failed to add to entitlements: ${entitlementError.message}`)
                        }

                        // Table 2: user_credits.looks_balance (used by client via get-credits, spend-credit)
                        const { error: creditsError } = await supabaseAdmin.rpc('add_credits', {
                            p_user_id: userId,
                            p_amount: creditsToAdd
                        })
                        if (creditsError) {
                            console.error(`❌ Failed to add to user_credits: ${creditsError.message}`)
                        }

                        if (!entitlementError && !creditsError) {
                            console.log(`✅ Added ${creditsToAdd} credits to both tables`)
                        }
                    }
                }

                return new Response(
                    JSON.stringify({ success: true, action: 'credits_added' }),
                    { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )

            default:
                console.log(`ℹ️ Unhandled event type: ${event.type}`)
                return new Response(
                    JSON.stringify({ success: true, message: 'Event type not handled' }),
                    { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
        }

        // 6. Update Supabase entitlements
        console.log(`🔄 Updating entitlements for user ${userId}: creator_mode_active = ${creatorModeActive}`)

        const { error: updateError } = await supabaseAdmin
            .from('entitlements')
            .upsert({
                user_id: userId,
                creator_mode_active: creatorModeActive,
                updated_at: new Date().toISOString()
            }, {
                onConflict: 'user_id'
            })

        if (updateError) {
            console.error(`❌ Failed to update entitlements: ${updateError.message}`)
            return new Response(
                JSON.stringify({ error: 'Database update failed', details: updateError.message }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // 7. Log the event for analytics
        await supabaseAdmin
            .from('monetization_events')
            .insert({
                user_id: userId,
                event_type: event.type,
                product_id: event.product_id,
                revenue: 0, // RevenueCat doesn't always send revenue in webhooks
                created_at: new Date().toISOString()
            })
            .then(() => console.log('📊 Monetization event logged'))
            .catch(err => console.log('⚠️ Failed to log monetization event:', err))

        console.log(`✅ Webhook processed: ${eventAction} for user ${userId}`)

        return new Response(
            JSON.stringify({
                success: true,
                action: eventAction,
                user_id: userId,
                creator_mode_active: creatorModeActive
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error('💥 Webhook error:', error)
        return new Response(
            JSON.stringify({ error: 'Internal server error', message: String(error) }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
