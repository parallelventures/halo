// Eclat - Monetization Decision Engine Edge Function
// Returns: { offer_key, surface, products[], highlight, copy_variant, should_show }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Cooldown settings (hours)
const SAME_OFFER_COOLDOWN_HOURS = 24
const ANY_OFFER_COOLDOWN_HOURS = 4
const MAX_DAILY_IMPRESSIONS = 2
const MAX_WEEKLY_IMPRESSIONS = 5

// Product catalog
const PRODUCTS = {
    entry: {
        id: 'entry_access',
        price: '$2.99',
        looks_granted: 6,
    },
    pack_10: {
        id: '10looks',
        price: '$9.99',
        looks_granted: 10,
        label: '10 Looks',
        subtitle: 'Quick decision',
    },
    pack_30: {
        id: '30looks',
        price: '$22.99',
        looks_granted: 30,
        label: '30 Looks',
        subtitle: 'Enough to truly decide',
        badge: 'Most Popular',
    },
    pack_100: {
        id: '100looks',
        price: '$44.99',
        looks_granted: 100,
        label: '100 Looks',
        subtitle: 'Explore freely',
    },
    creator_mode: {
        id: 'creator_mode_weekly',
        price: '$12.99/week',
        label: 'Creator Mode',
        subtitle: 'Unlimited looks • Studio quality • No watermark',
    },
}

// Copy variants per segment
const COPY_VARIANTS = {
    TOURIST: {
        entry: {
            title: 'Unlock your first looks',
            subtitle: 'Preview your next hairstyle on you — instantly.',
            bullets: ['Realistic results', 'Made to look like you', 'Save & share'],
            cta: 'Unlock for $2.99',
            footnote: 'One-time purchase. No subscription.',
        },
        packs: {
            title: 'Get more looks',
            subtitle: 'Keep exploring — your next look is one tap away.',
            cta: 'Get 30 Looks',
            footnote: 'Looks never expire.',
        },
    },
    SAMPLER: {
        packs: {
            title: "You're out of looks",
            subtitle: 'Keep exploring — your next look is one tap away.',
            cta: 'Get 30 Looks',
        },
        creator_mode: {
            title: 'Creator Mode',
            subtitle: 'Create freely — without interruptions.',
            bullets: ['Unlimited looks', 'Studio-grade quality', 'No watermark'],
            cta: 'Enter Creator Mode — $12.99/week',
            secondary: 'Or get more looks',
            footnote: 'Renews weekly. Cancel anytime.',
        },
    },
    EXPLORER: {
        creator_mode: {
            title: 'Creator Mode',
            subtitle: "You're exploring deeply. Don't count looks.",
            bullets: ['Unlimited looks', 'Studio-grade quality', 'No watermark'],
            cta: 'Enter Creator Mode — $12.99/week',
            secondary: 'Buy looks instead',
            footnote: 'Most users choose Creator Mode once they start comparing.',
        },
    },
    BUYER: {
        creator_mode: {
            title: 'Make it effortless',
            subtitle: "You're buying looks often. Creator Mode is simpler.",
            bullets: ['Unlimited looks', 'Studio-grade quality', 'No watermark'],
            cta: 'Enter Creator Mode — $12.99/week',
            secondary: 'Continue with packs',
        },
    },
    POWER: {
        creator_mode: {
            title: 'Stay in flow',
            subtitle: 'Unlimited creation, no interruptions.',
            cta: 'Enter Creator Mode',
            secondary: 'Not now',
        },
    },
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
        )

        // Get auth token
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            return new Response(JSON.stringify({ error: 'No authorization header' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        // Get user from token
        const token = authHeader.replace('Bearer ', '')
        const { data: { user }, error: userError } = await supabaseClient.auth.getUser(token)

        if (userError || !user) {
            return new Response(JSON.stringify({ error: 'Invalid user' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        // Parse request body
        const { event, context = {} } = await req.json()
        // event: 'out_of_looks' | 'generation_success' | 'save_result' | 'share_result' | 'app_open' | 'try_generate'
        // context: { last_generation_status?, is_delight_moment?, attempt_second_pack? }

        // ===============================================
        // 1. Get user profile and entitlements
        // ===============================================
        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('primary_segment, lifecycle_state, tags, looks_used_total, saves_count, shares_count')
            .eq('id', user.id)
            .single()

        const { data: entitlements } = await supabaseClient
            .from('entitlements')
            .select('looks_balance, creator_mode_active, has_entry_access, total_packs_purchased')
            .eq('user_id', user.id)
            .single()

        // 🚨 FIX: Also read from user_credits (source of truth for client balance)
        // entitlements.looks_balance doesn't get decremented when client spends looks
        const { data: userCredits } = await supabaseClient
            .from('user_credits')
            .select('looks_balance')
            .eq('user_id', user.id)
            .single()

        if (!profile || !entitlements) {
            return new Response(JSON.stringify({ should_show: false, reason: 'no_profile' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        // Use the real balance from user_credits if available, otherwise fallback to entitlements
        const realLooksBalance = userCredits?.looks_balance ?? entitlements.looks_balance ?? 0
        // Override entitlements.looks_balance with the real one for downstream logic
        entitlements.looks_balance = realLooksBalance

        // ===============================================
        // 2. Check if user is in Creator Mode (no offers)
        // ===============================================
        if (entitlements.creator_mode_active) {
            return new Response(JSON.stringify({ should_show: false, reason: 'creator_mode_active' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        // ===============================================
        // 3. Check cooldowns and impression limits
        // ===============================================

        // Daily impressions
        const { data: dailyImpressions } = await supabaseClient
            .from('offer_impressions')
            .select('id')
            .eq('user_id', user.id)
            .gte('created_at', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString())

        if (dailyImpressions && dailyImpressions.length >= MAX_DAILY_IMPRESSIONS) {
            return new Response(JSON.stringify({ should_show: false, reason: 'daily_limit_reached' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        // Weekly impressions
        const { data: weeklyImpressions } = await supabaseClient
            .from('offer_impressions')
            .select('id')
            .eq('user_id', user.id)
            .gte('created_at', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString())

        if (weeklyImpressions && weeklyImpressions.length >= MAX_WEEKLY_IMPRESSIONS) {
            return new Response(JSON.stringify({ should_show: false, reason: 'weekly_limit_reached' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        // ===============================================
        // 4. Never show after failed generation
        // ===============================================
        if (context.last_generation_status === 'failed') {
            return new Response(JSON.stringify({ should_show: false, reason: 'after_failure' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        // ===============================================
        // 5. Decide which offer to show based on event + segment
        // ===============================================
        const segment = profile.primary_segment || 'TOURIST'
        let offerKey: string
        let surface: string
        let products: any[] = []
        let highlight: string
        let copyVariant: any

        switch (event) {
            case 'try_generate':
                // First-time generate attempt
                if (!entitlements.has_entry_access && entitlements.looks_balance === 0) {
                    offerKey = 'entry'
                    surface = 'sheet'
                    products = [PRODUCTS.entry]
                    highlight = 'entry_access'
                    copyVariant = COPY_VARIANTS.TOURIST.entry
                } else {
                    return new Response(JSON.stringify({ should_show: false, reason: 'has_access' }), {
                        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                    })
                }
                break

            case 'out_of_looks':
                // Check cooldown for any offer
                const { data: lastImpression } = await supabaseClient
                    .from('offer_impressions')
                    .select('created_at')
                    .eq('user_id', user.id)
                    .order('created_at', { ascending: false })
                    .limit(1)
                    .single()

                if (lastImpression) {
                    const hoursSinceLastOffer = (Date.now() - new Date(lastImpression.created_at).getTime()) / (1000 * 60 * 60)
                    if (hoursSinceLastOffer < ANY_OFFER_COOLDOWN_HOURS) {
                        return new Response(JSON.stringify({ should_show: false, reason: 'cooldown_active' }), {
                            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                        })
                    }
                }

                // Decide based on segment
                if (segment === 'TOURIST') {
                    // Tourist without entry: show entry first
                    if (!entitlements.has_entry_access) {
                        offerKey = 'entry'
                        surface = 'sheet'
                        products = [PRODUCTS.entry]
                        highlight = 'entry_access'
                        copyVariant = COPY_VARIANTS.TOURIST.entry
                    } else {
                        // Has entry, show packs
                        offerKey = 'packs'
                        surface = 'sheet'
                        products = [PRODUCTS.pack_10, PRODUCTS.pack_30, PRODUCTS.pack_100]
                        highlight = '30looks'
                        copyVariant = COPY_VARIANTS.TOURIST.packs
                    }
                } else if (segment === 'SAMPLER') {
                    // Sampler: Creator Mode soft, packs as secondary
                    offerKey = 'creator_mode'
                    surface = 'sheet'
                    products = [PRODUCTS.creator_mode, PRODUCTS.pack_10, PRODUCTS.pack_30, PRODUCTS.pack_100]
                    highlight = 'creator_mode_weekly'
                    copyVariant = COPY_VARIANTS.SAMPLER.creator_mode
                } else if (segment === 'EXPLORER' || segment === 'BUYER' || segment === 'POWER') {
                    // Explorer/Buyer/Power: Creator Mode as primary
                    offerKey = 'creator_mode'
                    surface = segment === 'POWER' ? 'sheet' : 'sheet'
                    products = [PRODUCTS.creator_mode, PRODUCTS.pack_10, PRODUCTS.pack_30, PRODUCTS.pack_100]
                    highlight = 'creator_mode_weekly'
                    copyVariant = COPY_VARIANTS[segment]?.creator_mode || COPY_VARIANTS.EXPLORER.creator_mode
                } else {
                    // Fallback
                    offerKey = 'packs'
                    surface = 'sheet'
                    products = [PRODUCTS.pack_10, PRODUCTS.pack_30, PRODUCTS.pack_100]
                    highlight = '30looks'
                    copyVariant = COPY_VARIANTS.TOURIST.packs
                }
                break

            case 'save_result':
            case 'share_result':
                // Delight moment - soft Creator Mode upsell
                if (!entitlements.has_entry_access) {
                    return new Response(JSON.stringify({ should_show: false, reason: 'no_entry_yet' }), {
                        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                    })
                }

                // Check Creator Mode cooldown specifically
                const { data: lastCreatorOffer } = await supabaseClient
                    .from('offer_impressions')
                    .select('created_at')
                    .eq('user_id', user.id)
                    .eq('offer_key', 'creator_mode')
                    .order('created_at', { ascending: false })
                    .limit(1)
                    .single()

                if (lastCreatorOffer) {
                    const hoursSince = (Date.now() - new Date(lastCreatorOffer.created_at).getTime()) / (1000 * 60 * 60)
                    if (hoursSince < SAME_OFFER_COOLDOWN_HOURS) {
                        return new Response(JSON.stringify({ should_show: false, reason: 'creator_mode_cooldown' }), {
                            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                        })
                    }
                }

                offerKey = 'creator_mode'
                surface = 'pill' // Soft, non-interrupting
                products = [PRODUCTS.creator_mode]
                highlight = 'creator_mode_weekly'
                copyVariant = {
                    title: 'Create freely this week',
                    cta: 'Try Creator Mode',
                }
                break

            case 'attempt_second_pack':
                // Intercept with Creator Mode
                if (entitlements.total_packs_purchased >= 1) {
                    offerKey = 'creator_mode'
                    surface = 'fullscreen'
                    products = [PRODUCTS.creator_mode]
                    highlight = 'creator_mode_weekly'
                    copyVariant = COPY_VARIANTS.BUYER.creator_mode
                } else {
                    return new Response(JSON.stringify({ should_show: false, reason: 'first_pack' }), {
                        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                    })
                }
                break

            default:
                return new Response(JSON.stringify({ should_show: false, reason: 'unknown_event' }), {
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                })
        }

        // ===============================================
        // 6. Return the offer decision
        // ===============================================
        return new Response(JSON.stringify({
            should_show: true,
            offer_key: offerKey,
            surface: surface,
            products: products,
            highlight: highlight,
            copy_variant: copyVariant,
            segment: segment,
            looks_balance: entitlements.looks_balance,
        }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })

    } catch (error) {
        console.error('Error in decide-offer:', error)
        return new Response(JSON.stringify({
            should_show: false,
            error: error.message,
            reason: 'error'
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
    }
})
