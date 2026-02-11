//
//  VariantBPaywallView.swift
//  Eclat
//
//  Placeholder — not currently used
//

import SwiftUI

struct VariantBPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Text("Variant B — not active")
            .onAppear { dismiss() }
    }
}
