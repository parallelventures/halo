# Push Notifications Setup Guide

## APNs Configuration in Apple Developer Portal

### Step 1: Create Push Notification Key

1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Go to **Keys** in the sidebar
4. Click the **+** button to create a new key
5. Name it: `Eclat Push Notifications`
6. Check **Apple Push Notifications service (APNs)**
7. Click **Continue**, then **Register**
8. **Download the key** (`.p8` file) - save it securely!
9. Note down:
   - **Key ID** (10-character alphanumeric)
   - **Team ID** (from your account settings)

### Step 2: Add Push Capability in Xcode

The entitlement is already configured in `Eclat.entitlements`:
```xml
<key>aps-environment</key>
<string>development</string>
```

For production, change to:
```xml
<key>aps-environment</key>
<string>production</string>
```

### Step 3: Configure Push in Supabase (Optional - for server-side pushes)

If you want to send pushes from Supabase Edge Functions:

1. Go to Supabase Dashboard → Settings → Edge Functions
2. Add environment variables:
   - `APNS_KEY_ID`: Your Key ID
   - `APNS_TEAM_ID`: Your Team ID
   - `APNS_KEY_CONTENT`: Contents of your .p8 file (base64 encoded)
   - `APNS_BUNDLE_ID`: `eu.parallelventures.eclat`

### Step 4: Test Push Notifications

In Xcode Simulator or on a real device:

1. Build and run the app
2. Complete a generation (win moment)
3. Accept notification permission
4. Check console for: `📱 Device token: ...`

To test manually:
```bash
# Using APNs API directly (requires token)
curl -v POST \
  --header "apns-topic: eu.parallelventures.eclat" \
  --header "apns-push-type: alert" \
  --header "authorization: bearer <JWT>" \
  --data '{"aps":{"alert":{"title":"Eclat","body":"See yourself differently today."}}}' \
  https://api.push.apple.com/3/device/<device_token>
```

---

## Deep Links Configuration

### URL Scheme Setup

Add to `Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>eclat</string>
        </array>
        <key>CFBundleURLName</key>
        <string>eu.parallelventures.eclat</string>
    </dict>
</array>
```

### Supported Deep Links

| URL | Action |
|-----|--------|
| `eclat://home` | Navigate to home screen |
| `eclat://history` | Open history sheet |
| `eclat://creator-mode` | Open credits paywall |
| `eclat://packs` | Open credits paywall |
| `eclat://style/<id>` | Navigate to specific style |
| `eclat://result/<id>` | Open specific result |

---

## Testing Checklist

- [ ] Build app on real device
- [ ] Complete first generation
- [ ] Accept notification permission
- [ ] Close app and wait 24h (or manually schedule)
- [ ] Tap notification to verify deep link
- [ ] Make a purchase and verify post-purchase notification scheduling
