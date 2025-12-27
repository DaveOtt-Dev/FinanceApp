//
//  AccountRowView.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//

import SwiftUI

struct BankAccountRowItem: View {
    var _account: PlaidAccount
    @State var _showAccountInfo: Bool
    
    init(account: PlaidAccount) {
        _account = account
        _showAccountInfo = false
    }

    var body: some View {
        Button(action: {
            _showAccountInfo = true
        }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(_account.name)
                        .font(.headline)

                    Text(_account.getSubtype)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(_account.available!.formattedAsCurrency())
                        .font(.headline)
                        .monospacedDigit()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $_showAccountInfo) {
            BankAccountInfoView(account: _account)
        }
    }
}
