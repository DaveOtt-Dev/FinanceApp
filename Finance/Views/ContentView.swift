//
//  ContentView.swift
//  Finance
//
//  Created by David Ott on 11/22/25.
//

import SwiftUI

struct ContentView: View {
    // This will eventually come from your data layer
    @State private var netWorth: Double = 125_000.00

    var body: some View {
        // Net Worth Section
        VStack(alignment: .leading, spacing: 4) {
            NetWorthView()
            BankAccountsView()
            CreditCardsView()
        }.padding()
        
        Spacer()
        
        // Placeholder for future content
        Text("Accounts, budgets, and transactions coming soon.")
            .foregroundColor(.secondary)
        
        Spacer()
    }
}

#Preview {
    ContentView()
}
