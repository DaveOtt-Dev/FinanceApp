//
//  CreditCardRowView.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//
import SwiftUI

struct CreditCardRowItem: View {
    let _account: PlaidAccount

    var body: some View {
        Button(action: {
            print("Credit card account clicked")
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
                    Text(_account.current.formattedAsCurrency())
                        .font(.headline)
                        .monospacedDigit()
                    
                    if let utilization = _account.utilizationPercentage {
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
        .buttonStyle(.plain)
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
