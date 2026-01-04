//
//  ContentView.swift
//  Halo
//
//  Main content view - placeholder for Xcode project structure
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager())
}
