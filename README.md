# 🌟 Halo - AI Hairstyle Try-On

An iOS app that lets users try on different hairstyles using AI-powered image generation.

## ✨ Features

- **Quick Onboarding** - Beautiful 3-step introduction
- **Selfie Capture** - Camera or photo library selection
- **AI Hairstyle Generation** - Powered by Google Gemini (Nano Banana Pro)
- **Blurred Preview** - Results are blurred until subscription
- **Subscription Model** - Monthly ($19.99) or Annual ($69.99)
- **StoreKit 2** - Modern subscription management

## 🏗️ Architecture

```
Halo/
├── HaloApp.swift              # App entry point
├── ContentView.swift          # Root content view
├── Info.plist                 # App configuration
│
├── App/
│   ├── RootView.swift         # Navigation controller
│   └── AppState.swift         # Global state management
│
├── Core/
│   ├── Config/
│   │   └── APIConfig.swift    # API configuration & feature flags
│   │
│   ├── Design/
│   │   ├── Theme.swift        # Colors, typography, spacing
│   │   ├── Animations.swift   # Custom animations & haptics
│   │   └── Components.swift   # Reusable UI components
│   │
│   ├── Extensions/
│   │   └── Extensions.swift   # Swift utilities
│   │
│   ├── Network/
│   │   ├── NetworkService.swift  # Base networking
│   │   └── GeminiAPI.swift       # Gemini API integration
│   │
│   └── Services/
│       └── SubscriptionManager.swift  # StoreKit 2
│
└── Features/
    ├── Onboarding/
    │   └── OnboardingView.swift
    │
    ├── Camera/
    │   ├── CameraService.swift
    │   └── CameraView.swift
    │
    ├── Processing/
    │   └── ProcessingView.swift
    │
    ├── Result/
    │   └── ResultView.swift
    │
    ├── Paywall/
    │   └── PaywallView.swift
    │
    └── Home/
        └── HomeView.swift
```

## 🚀 Getting Started

### Prerequisites

- Xcode 15.0+
- iOS 17.0+
- Google AI Studio API Key

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/halo-ios.git
   cd halo-ios
   ```

2. **Configure API Key**
   
   Option A: Environment Variable
   ```bash
   export GEMINI_API_KEY="your-api-key-here"
   ```
   
   Option B: In `APIConfig.swift`
   ```swift
   return "your-api-key-here"
   ```

3. **Open in Xcode**
   ```bash
   open Halo.xcodeproj
   ```

4. **Configure Signing**
   - Select your development team
   - Update bundle identifier

5. **Run the app**
   - Select a simulator or device
   - Press Cmd + R

## 🎨 Design System

### Colors
- **Primary**: Purple gradient (`#B266FF` → `#FF6B9D`)
- **Background**: Dark (`#0A0A0F`)
- **Text**: White/Gray hierarchy

### Typography
- SF Rounded (system)
- Display: 40/32/28pt
- Headlines: 24/20/18pt
- Body: 17/15/13pt

### Animations
- Spring animations with bezier curves
- Custom `haloSpring`, `haloEaseOut`, `haloBack`
- Haptic feedback on interactions

## 💰 Subscription Setup

1. **App Store Connect**
   - Create subscription products:
     - `com.halo.subscription.monthly` - $19.99/month
     - `com.halo.subscription.annual` - $69.99/year

2. **Update Product IDs**
   - Edit `SubscriptionProduct` enum in `SubscriptionManager.swift`

3. **Configure StoreKit Testing**
   - Add StoreKit configuration file for testing

## 🔒 Security Notes

- **API Keys**: Never commit real API keys. Use environment variables or a secrets manager.
- **Server Proxy**: For production, proxy Gemini API calls through your backend.
- **Obfuscation**: Consider code obfuscation for release builds.

## 📱 Screens

| Screen | Description |
|--------|-------------|
| Onboarding | 3-step intro with animations |
| Camera | Selfie capture with face guide |
| Processing | AI generation with progress |
| Result | Blurred preview → Paywall |
| Paywall | Subscription options |
| Home | Returning user dashboard |

## 🔧 Configuration

### Feature Flags
Edit `FeatureFlags` in `APIConfig.swift`:
- `isDebugModeEnabled`
- `showOnboarding`
- `enableHaptics`
- `enableAnalytics`

### Gemini API
- Model: `gemini-2.5-flash-image`
- Supports image-to-image editing
- 120s timeout for generation

## 📄 License

This project is proprietary. All rights reserved.

## 👤 Author

Built with ❤️ for amazing hair transformations.
