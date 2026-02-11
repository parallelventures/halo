//
//  TrialConversionView.swift
//  Eclat
//
//  Placeholder — not currently used
//

import SwiftUI

struct TrialConversionView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Text("Trial Conversion — not active")
            .onAppear { dismiss() }
    }
}
