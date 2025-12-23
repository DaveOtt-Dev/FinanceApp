//
//  CreditCardRowView.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//
import SwiftUI

struct CreditCardRowView: View {
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
                Text(account.current.formattedAsCurrency())
                    .font(.headline)
                    .monospacedDigit()
                
                if let utilization = account.utilizationPercentage {
                    Text("Utilization: ")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    +
                    Text("\(utilization)%")
                        .font(.subheadline)
                        .foregroundColor(utilizationColor(utilization))
                        .monospacedDigit()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
    
    func utilizationColor(_ utilization: Int) -> Color {
        switch utilization {
        case 0...30: return .green
        case 31...50: return .yellow
        case 51...75: return .orange
        default: return .red
        }
    }
}
