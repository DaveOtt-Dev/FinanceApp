//
//  CreditCardsView.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//
import SwiftUI

struct CreditCardsView: View {
    @State private var creditCards: [CreditCard] = [
        CreditCard(name: "Visa Platinum", type: "Credit Card", balance: 1_200.50, limit: 5_000),
        CreditCard(name: "Mastercard Rewards", type: "Credit Card", balance: 560.75, limit: 3_000),
        CreditCard(name: "Amex Gold", type: "Credit Card", balance: 2_350.00, limit: 10_000)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Credit Cards")
                .font(.headline)
                .padding(.top, 20)
            
            // List of accounts
            ForEach(creditCards) { creditCard in
                CreditCardRowView(creditCard: creditCard)
            }
        }
    }
}

#Preview {
    CreditCardsView()
}
