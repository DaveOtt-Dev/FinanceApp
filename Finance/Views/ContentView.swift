//
//  ContentView.swift
//  Finance
//
//  Created by David Ott on 11/22/25.
//

import SwiftUI

struct ContentView: View {
    @State private var bankAccounts: [PlaidAccount] = []
    @State private var creditCards: [PlaidAccount] = []
    @State private var accountsLoaded = false
    
    var body: some View {
        VStack {
            if accountsLoaded {
                VStack(alignment: .leading, spacing: 4) {
                    let netWorth: Double = getNetWorth()
                    
                    NetWorthView(netWorth: netWorth)
                    BankAccountsView(accounts: bankAccounts)
                    CreditCardsView(accounts: creditCards)
                }
                .padding()
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Other accounts, budgets, and transactions coming soon.")
                    .foregroundColor(.secondary)
            }
            
            
            Spacer()
        }
        .task {
            do {
                let fetchedAccounts = try await PlaidAPI.shared.getAccounts()
                
                var banks: [PlaidAccount] = []
                var credits: [PlaidAccount] = []
                
                for account in fetchedAccounts {
                    switch account.type {
                    case "depository":
                        banks.append(account)
                    case "credit":
                        credits.append(account)
                    default:
                        break
                    }
                }
                
                bankAccounts = banks
                creditCards = credits
                accountsLoaded = true
            } catch {
                print("Failed to fetch accounts: \(error)")
                accountsLoaded = true
            }
        }
    }
    
    func getNetWorth() -> Double {
        let bankTotal = bankAccounts.reduce(0) { $0 + $1.current }
        let creditTotal = creditCards.reduce(0) { $0 + $1.current }
        let netWorth = bankTotal - creditTotal
        
        return netWorth
    }
}

#Preview {
    ContentView()
}
