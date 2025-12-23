//
//  AccountRowView.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//

import SwiftUI

struct BankAccountRowView: View {
    let account: PlaidAccount

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(account.name)
                    .font(.headline)

                Text(account.getSubtype)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(account.available!.formattedAsCurrency())
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
}
