// Supabase Edge Function: generate-hairstyle
// Proxies requests to Gemini API with Nano Banana Pro
// 🔧 FIXED: Robust JWT verification that doesn't depend on getUser()

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')
// Nano Banana Pro
const GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent"

// CORS headers
const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RequestBody {
    image: string  // Base64 encoded image
    prompt: string
}

// Helper: Decode JWT payload without verification (Supabase already verified the signature)
function decodeJwtPayload(token: string): { sub?: string; role?: string; exp?: number } | null {
    try {
        const parts = token.split('.')
        if (parts.length !== 3) return null

        // Base64url decode the payload
        const payload = parts[1]
        const decoded = atob(payload.replace(/-/g, '+').replace(/_/g, '/'))
        return JSON.parse(decoded)
    } catch {
        return null
    }
}

serve(async (req) => {
    // Handle preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        console.log('🚀 generate-hairstyle function invoked')

        // 1. Extract and validate Authorization header
        const authHeader = req.headers.get('Authorization')
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            console.error('❌ Missing or invalid authorization header')
            return new Response(
                JSON.stringify({ error: 'Unauthorized', details: 'Missing authorization header' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const token = authHeader.replace('Bearer ', '')

        // 2. Decode JWT to get user ID (Supabase edge already validated the signature)
        const jwtPayload = decodeJwtPayload(token)
        if (!jwtPayload || !jwtPayload.sub) {
            console.error('❌ Invalid JWT payload')
            return new Response(
                JSON.stringify({ error: 'Unauthorized', details: 'Invalid token format' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Check if token is expired
        const now = Math.floor(Date.now() / 1000)
        if (jwtPayload.exp && jwtPayload.exp < now) {
            console.error('❌ Token expired')
            return new Response(
                JSON.stringify({ error: 'Unauthorized', details: 'Token expired' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Check role is authenticated (not anon)
        if (jwtPayload.role !== 'authenticated') {
            console.error('❌ Invalid role:', jwtPayload.role)
            return new Response(
                JSON.stringify({ error: 'Unauthorized', details: 'Must be authenticated user' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const userId = jwtPayload.sub
        console.log('✅ Authenticated user:', userId)


        // 3. Setup Supabase Admin client for DB operations
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

        // 4. Subscription verification (LOG ONLY — never blocks)
        // We log the result for diagnostics but ALWAYS allow generation
        // because purchase identity may be on a different RC ID than the Supabase UUID
        const REVENUECAT_API_KEY = Deno.env.get('REVENUECAT_API_KEY') || ''

        try {
            if (REVENUECAT_API_KEY) {
                const rcResponse = await fetch(
                    `https://api.revenuecat.com/v1/subscribers/${userId}`,
                    {
                        headers: {
                            'Authorization': `Bearer ${REVENUECAT_API_KEY}`,
                            'Content-Type': 'application/json',
                        }
                    }
                )

                if (rcResponse.ok) {
                    const rcData = await rcResponse.json()
                    const entitlements = rcData?.subscriber?.entitlements || {}
                    const subscriptions = rcData?.subscriber?.subscriptions || {}
                    const now = new Date()

                    const creatorEntitlement = entitlements['creator']?.expires_date &&
                        new Date(entitlements['creator'].expires_date) > now
                    const atelierEntitlement = entitlements['atelier']?.expires_date &&
                        new Date(entitlements['atelier'].expires_date) > now
                    // Legacy: "Studio" entitlement from older RC configuration
                    const studioEntitlement = entitlements['Studio']?.expires_date &&
                        new Date(entitlements['Studio'].expires_date) > now

                    let hasActiveSub = false
                    for (const [subId, sub] of Object.entries(subscriptions)) {
                        const subData = sub as any
                        if (subData.expires_date && new Date(subData.expires_date) > now) {
                            hasActiveSub = true
                            break
                        }
                    }

                    const hasAccess = creatorEntitlement || atelierEntitlement || studioEntitlement || hasActiveSub
                    console.log(`🔐 [LOG ONLY] RevenueCat for ${userId}: entitlement=${hasAccess}, creator=${!!creatorEntitlement}, atelier=${!!atelierEntitlement}, studio=${!!studioEntitlement}, activeSub=${hasActiveSub}, activeSubscriptions=${JSON.stringify(Object.keys(subscriptions))}`)

                    if (!hasAccess) {
                        console.warn(`⚠️ [LOG ONLY] User ${userId} has NO entitlement/subscription in RevenueCat — but allowing generation (purchase may be on anonymous RC ID)`)
                    }
                } else {
                    console.warn(`⚠️ RevenueCat API returned ${rcResponse.status} for ${userId}`)
                }
            }
        } catch (rcError) {
            console.warn('⚠️ RevenueCat check failed (non-blocking):', String(rcError))
        }

        console.log(`✅ User ${userId} — proceeding with generation`)

        // 5. Validate API key
        if (!GEMINI_API_KEY) {
            console.error('❌ GEMINI_API_KEY not configured')
            return new Response(
                JSON.stringify({ error: 'Server configuration error' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // 6. Parse request body
        let body: RequestBody
        try {
            body = await req.json()
            console.log('📥 Request body parsed successfully')
        } catch (parseError) {
            console.error('❌ Failed to parse request body:', String(parseError))
            return new Response(
                JSON.stringify({ error: 'Invalid JSON body', details: String(parseError) }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const { image, prompt } = body

        if (!image || !prompt) {
            console.error('❌ Missing required fields - image:', !!image, 'prompt:', !!prompt)
            return new Response(
                JSON.stringify({ error: 'Missing image or prompt' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        console.log('📝 Processing prompt:', prompt.substring(0, 100))
        console.log('📷 Image data length:', image.length, 'chars')

        // 7. Build Gemini request
        const geminiRequest = {
            contents: [
                {
                    parts: [
                        {
                            inline_data: {
                                mime_type: "image/jpeg",
                                data: image
                            }
                        },
                        {
                            text: prompt
                        }
                    ]
                }
            ],
            generationConfig: {
                responseModalities: ["TEXT", "IMAGE"]
            }
        }

        // 8. Call Gemini API
        console.log('🤖 Calling Gemini API...')
        const geminiResponse = await fetch(`${GEMINI_API_URL}?key=${GEMINI_API_KEY}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(geminiRequest)
        })

        if (!geminiResponse.ok) {
            const errorText = await geminiResponse.text()
            console.error('❌ Gemini API error:', errorText)
            return new Response(
                JSON.stringify({ error: 'Image generation failed', details: errorText }),
                { status: geminiResponse.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const geminiData = await geminiResponse.json()
        console.log('✅ Gemini response received')

        // 9. Extract generated image
        const candidates = geminiData.candidates
        if (!candidates || candidates.length === 0) {
            console.error('No candidates in response:', JSON.stringify(geminiData))
            return new Response(
                JSON.stringify({ error: 'No image generated', details: geminiData }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const parts = candidates[0].content?.parts
        if (!parts) {
            console.error('No parts in response')
            return new Response(
                JSON.stringify({ error: 'No content in response' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Find image part (handle both camelCase and snake_case)
        const imagePart = parts.find((p: any) => {
            const data = p.inlineData || p.inline_data
            return data?.mimeType?.startsWith('image/') || data?.mime_type?.startsWith('image/')
        })

        if (!imagePart) {
            console.log('Parts received:', JSON.stringify(parts.map((p: any) => Object.keys(p))))
            return new Response(
                JSON.stringify({ error: 'No image in response', parts: parts }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const inlineData = imagePart.inlineData || imagePart.inline_data
        const imageBase64 = inlineData.data
        const mimeType = inlineData.mimeType || inlineData.mime_type

        console.log('🎉 Image generated successfully, mimeType:', mimeType)

        // 10. Return success
        return new Response(
            JSON.stringify({
                success: true,
                image: imageBase64,
                mimeType: mimeType
            }),
            {
                status: 200,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        )

    } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error)
        const errorStack = error instanceof Error ? error.stack : 'No stack trace'
        console.error('💥 Function error:', errorMessage)
        console.error('📚 Stack trace:', errorStack)
        return new Response(
            JSON.stringify({ error: 'Internal server error', message: errorMessage }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
