// Supabase Edge Function: generate-hairstyle
// Proxies requests to Gemini API with Nano Banana Pro

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')
// Nano Banana Pro
const GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent"

interface RequestBody {
    image: string  // Base64 encoded image
    prompt: string
}

serve(async (req) => {
    // CORS headers
    const corsHeaders = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    }

    // Handle preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Validate API key is configured
        if (!GEMINI_API_KEY) {
            console.error('GEMINI_API_KEY not configured')
            return new Response(
                JSON.stringify({ error: 'Server configuration error' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Parse request
        const { image, prompt }: RequestBody = await req.json()

        if (!image || !prompt) {
            return new Response(
                JSON.stringify({ error: 'Missing image or prompt' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        console.log('Processing request with prompt:', prompt.substring(0, 100))

        // Build Gemini request for Nano Banana Pro (image editing)
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

        // Call Gemini API
        console.log('Calling Gemini API (Nano Banana Pro)...')
        const geminiResponse = await fetch(`${GEMINI_API_URL}?key=${GEMINI_API_KEY}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(geminiRequest)
        })

        if (!geminiResponse.ok) {
            const errorText = await geminiResponse.text()
            console.error('Gemini API error:', errorText)
            return new Response(
                JSON.stringify({ error: 'Image generation failed', details: errorText }),
                { status: geminiResponse.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const geminiData = await geminiResponse.json()
        console.log('Gemini response received')

        // Extract the generated image
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

        // Find image part - check both camelCase and snake_case
        const imagePart = parts.find((p: any) => {
            const data = p.inlineData || p.inline_data
            return data?.mimeType?.startsWith('image/') || data?.mime_type?.startsWith('image/')
        })

        if (!imagePart) {
            // Log what we did get
            console.log('Parts received:', JSON.stringify(parts.map((p: any) => Object.keys(p))))
            return new Response(
                JSON.stringify({ error: 'No image in response', parts: parts }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Get inline data (handle both casings)
        const inlineData = imagePart.inlineData || imagePart.inline_data
        const imageBase64 = inlineData.data
        const mimeType = inlineData.mimeType || inlineData.mime_type

        console.log('Image generated successfully, mimeType:', mimeType)

        // Return the generated image
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
        console.error('Function error:', error)
        return new Response(
            JSON.stringify({ error: 'Internal server error', message: String(error) }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
