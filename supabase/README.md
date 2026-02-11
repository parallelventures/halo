# Supabase Setup Guide

This folder contains the Supabase Edge Functions for the Eclat app.

## Prerequisites

1. Install Supabase CLI:
```bash
npm install -g supabase
```

2. Login to Supabase:
```bash
supabase login
```

## Setup

### 1. Link to your Supabase project

```bash
supabase link --project-ref YOUR_PROJECT_ID
```

### 2. Set the Gemini API Key as a secret

```bash
supabase secrets set GEMINI_API_KEY=your_actual_gemini_api_key
```

### 3. Deploy the Edge Function

```bash
supabase functions deploy generate-hairstyle
```

## iOS App Configuration

Update `SupabaseConfig` in `Eclat/Core/Network/GeminiAPI.swift`:

```swift
enum SupabaseConfig {
    static let projectURL = "https://YOUR_PROJECT_ID.supabase.co"
    static let anonKey = "YOUR_SUPABASE_ANON_KEY"
}
```

You can find these values in your Supabase Dashboard:
- **Project URL**: Settings → API → Project URL
- **Anon Key**: Settings → API → Project API keys → anon public

## Testing the Edge Function

You can test the function with curl:

```bash
curl -X POST 'https://YOUR_PROJECT_ID.supabase.co/functions/v1/generate-hairstyle' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "image": "BASE64_ENCODED_IMAGE",
    "prompt": "Apply a modern short hairstyle to this person"
  }'
```

## Security Notes

- The Gemini API key is stored as a Supabase secret and never leaves the server
- The `anonKey` is safe to include in the app - it only identifies your project
- All API calls are proxied through the Edge Function
- You can add rate limiting or user authentication in the Edge Function if needed

## Rate Limiting (Optional)

To add per-user rate limiting, you can:
1. Enable Supabase Auth
2. Check the `Authorization` header for a valid user
3. Track usage in a Supabase table
4. Reject requests that exceed the limit
