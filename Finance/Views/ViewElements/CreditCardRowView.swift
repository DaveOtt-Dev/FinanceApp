//
//  CreditCardRowView.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//
import SwiftUI

struct CreditCardRowView: View {
    let creditCard: CreditCard

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(creditCard.name)
                    .font(.headline)

                Text(creditCard.type)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(creditCard.balance.formattedAsCurrency())
                    .font(.headline)
                    .monospacedDigit()
                
                Text("\(creditCard.utilizationPercentage)%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}
