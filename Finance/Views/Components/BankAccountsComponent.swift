//
//  BankAccountsView.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//
import SwiftUI

struct BankAccountsComponent: View {
    @State private var _accounts: [PlaidAccount]
    
    init(accounts: [PlaidAccount]) {
        _accounts = accounts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bank Accounts")
                .font(.headline)
                .padding(.top, 20)
            
            // List of accounts
            ForEach(_accounts) { account in
                BankAccountRowItem(account: account)
            }
        }
    }
}
