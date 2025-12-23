//
//  CreditCard.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//
import Foundation

struct CreditCard: Identifiable, Codable {
    var id = UUID()
    let name: String
    let type: String
    let balance: Double
    let limit: Double
    
    // Get-only property returning a decimal (e.g., 0.45)
    var utilization: Double {
        balance / limit
    }
    
    // Get-only property returning a percentage (e.g., 45.0)
    var utilizationPercentage: Int {
        Int((balance / limit) * 100.rounded())
    }
}
