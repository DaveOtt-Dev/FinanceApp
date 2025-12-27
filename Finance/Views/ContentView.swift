//
//  ContentView.swift
//  Finance
//
//  Created by David Ott on 11/22/25.
//

import SwiftUI

struct ContentView: View {
    @State private var _bankAccounts: [PlaidAccount] = []
    @State private var _creditCards: [PlaidAccount] = []
    @State private var _accountsLoaded = false
    
    var body: some View {
        VStack {
            if _accountsLoaded {
                AccountsView(bankAccounts: _bankAccounts, creditCards: _creditCards)
            } else {
                LoadingView()
            }
        }
        .task {
            do {
                let token = try await PlaidAPI.shared.createLinkToken()
                print(token)
                
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
                
                _bankAccounts = banks
                _creditCards = credits
                _accountsLoaded = true
            } catch {
                print("Failed to fetch accounts: \(error)")
                _accountsLoaded = true
            }
        }
    }
}

#Preview {
    ContentView()
}
