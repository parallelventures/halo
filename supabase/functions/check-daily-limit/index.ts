// Edge Function: check-daily-limit
// Checks and tracks daily generation limit (8/day per user)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const DAILY_LIMIT = 20
const RESET_HOURS = 24

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Get user from auth header
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            throw new Error('Missing authorization header')
        }

        // Create Supabase clients
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: authHeader } } }
        )

        const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
        if (userError || !user) {
            throw new Error('Unauthorized')
        }

        // Parse request body
        const { action = 'check' } = await req.json()

        // Get or create daily limit record for user
        const now = new Date()
        const twentyFourHoursAgo = new Date(now.getTime() - (RESET_HOURS * 60 * 60 * 1000))

        // Fetch user's generations in the last 24 hours
        const { data: recentGenerations, error: fetchError } = await supabaseAdmin
            .from('generations')
            .select('id, created_at')
            .eq('user_id', user.id)
            .gte('created_at', twentyFourHoursAgo.toISOString())
            .order('created_at', { ascending: true })

        if (fetchError) {
            console.error('Error fetching generations:', fetchError)
            // Fallback to allowing generation if we can't check
            return new Response(
                JSON.stringify({
                    can_generate: true,
                    count: 0,
                    limit: DAILY_LIMIT,
                    reset_in_minutes: 0,
                    error: 'Could not verify limit'
                }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
            )
        }

        const count = recentGenerations?.length || 0
        const canGenerate = count < DAILY_LIMIT

        // Calculate reset time (time until oldest generation is > 24h old)
        let resetInMinutes = 0
        if (!canGenerate && recentGenerations && recentGenerations.length > 0) {
            const oldestGeneration = new Date(recentGenerations[0].created_at)
            const resetTime = new Date(oldestGeneration.getTime() + (RESET_HOURS * 60 * 60 * 1000))
            resetInMinutes = Math.max(0, Math.ceil((resetTime.getTime() - now.getTime()) / (60 * 1000)))
        }

        // Format reset time as human-readable
        let resetTimeFormatted = 'now'
        if (resetInMinutes > 0) {
            const hours = Math.floor(resetInMinutes / 60)
            const minutes = resetInMinutes % 60
            if (hours > 0) {
                resetTimeFormatted = `${hours}h ${minutes}m`
            } else {
                resetTimeFormatted = `${minutes} minutes`
            }
        }

        return new Response(
            JSON.stringify({
                can_generate: canGenerate,
                count: count,
                limit: DAILY_LIMIT,
                remaining: Math.max(0, DAILY_LIMIT - count),
                reset_in_minutes: resetInMinutes,
                reset_time_formatted: resetTimeFormatted
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        )
    } catch (error) {
        console.error('Error:', error.message)
        return new Response(
            JSON.stringify({ error: error.message, can_generate: true }), // Allow on error
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400,
            }
        )
    }
})
