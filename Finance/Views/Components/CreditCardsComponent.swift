//
//  CreditCardsView.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//
import SwiftUI

struct CreditCardsComponent: View {
    @State private var _accounts: [PlaidAccount]
    
    init(accounts: [PlaidAccount]) {
        _accounts = accounts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Credit Cards")
                .font(.headline)
                .padding(.top, 20)
            
            if !_accounts.isEmpty {
                // List of accounts
                ForEach(_accounts) { account in
                    CreditCardRowItem(_account: account)
                }
            } else {
                Text("No accounts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
