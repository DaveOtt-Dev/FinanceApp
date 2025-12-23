//
//  NetWorthView.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//
import SwiftUI

struct NetWorthView: View {
    var netWorth: Double
    
    init(netWorth: Double) {
        self.netWorth = netWorth
    }

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
    NetWorthView(netWorth: 125000.00)
}
