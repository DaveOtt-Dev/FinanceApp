//
//  AccountRowView.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//

import SwiftUI

struct BankAccountRowView: View {
    let account: BankAccount

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(account.name)
                    .font(.headline)

                Text(account.type)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(account.balance.formattedAsCurrency())
                    .font(.subheadline)
                    .monospacedDigit()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}
