//
//  BankAccountsView.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//
import SwiftUI

struct BankAccountsView: View {
    @State private var accounts: [BankAccount] = [
        BankAccount(name: "Checking", type: "Bank Account", balance: 8_420.55),
        BankAccount(name: "Savings", type: "High-Yield Savings", balance: 32_100.00),
        BankAccount(name: "Brokerage", type: "Investment Account", balance: 84_479.45)
    ]

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

#Preview {
    BankAccountsView()
}
