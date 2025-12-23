//
//  NetWorthView.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//
import SwiftUI

struct NetWorthView: View {
    @State var netWorth: Double = 125_000.00

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Net Worth")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(netWorth.formattedAsCurrency())
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
}

#Preview {
    NetWorthView()
}
