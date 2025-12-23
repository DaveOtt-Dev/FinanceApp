//
//  CreditCardsView.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//
import SwiftUI

struct CreditCardsView: View {
    @State private var accounts: [PlaidAccount]
    
    init(accounts: [PlaidAccount]) {
        self.accounts = accounts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Credit Cards")
                .font(.headline)
                .padding(.top, 20)
            
            if !accounts.isEmpty {
                // List of accounts
                ForEach(self.accounts) { account in
                    CreditCardRowView(account: account)
                }
            } else {
                Text("No accounts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
