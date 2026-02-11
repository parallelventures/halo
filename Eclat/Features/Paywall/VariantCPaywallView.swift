//
//  VariantCPaywallView.swift
//  Eclat
//
//  Placeholder — not currently used
//

import SwiftUI

struct VariantCPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Text("Variant C — not active")
            .onAppear { dismiss() }
    }
}
