//
//  CurrencyFormatting.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//

import Foundation

extension Double {
    func formattedAsCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
}
