//
//  NetWorthView.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//
import SwiftUI

struct NetWorthComponent: View {
    var _netWorth: Double
    
    init(netWorth: Double) {
        _netWorth = netWorth
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Net Worth")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(_netWorth.formattedAsCurrency())
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
}

#Preview {
    NetWorthComponent(netWorth: 125000.00)
}
