//
//  BankAccountsView.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//
import SwiftUI

struct BankAccountsView: View {
    @State private var accounts: [PlaidAccount]
    
    init(accounts: [PlaidAccount]) {
        self.accounts = accounts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bank Accounts")
                .font(.headline)
                .padding(.top, 20)
            
            // List of accounts
            ForEach(accounts) { account in
                BankAccountRowView(account: account)
            }
        }
    }
}
