//
//  AccountsView.swift
//  Finance
//
//  Created by David Ott on 12/24/25.
//
import SwiftUI

struct AccountsView: View {
    @State private var _bankAccounts: [PlaidAccount]
    @State private var _creditCards: [PlaidAccount]
    @State private var _showPlaidInfo: Bool
    
    init(bankAccounts: [PlaidAccount], creditCards: [PlaidAccount]) {
        _bankAccounts = bankAccounts
        _creditCards = creditCards
        _showPlaidInfo = false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Accounts")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    _showPlaidInfo = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(8)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $_showPlaidInfo) {
                    AddAccountsView()
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .overlay(Divider(), alignment: .bottom)
        }
        
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                let netWorth: Double = getNetWorth()
                
                NetWorthComponent(netWorth: netWorth)
                BankAccountsComponent(accounts: _bankAccounts)
                CreditCardsComponent(accounts: _creditCards)
            }
            .padding()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Other accounts, budgets, and transactions coming soon.")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    func getNetWorth() -> Double {
        let bankTotal = _bankAccounts.reduce(0) { $0 + $1.current }
        let creditTotal = _creditCards.reduce(0) { $0 + $1.current }
        let netWorth = bankTotal - creditTotal
        
        return netWorth
    }
}
