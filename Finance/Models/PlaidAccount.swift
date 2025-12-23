//
//  PlaidAccount.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//
import Foundation

// MARK: - Plaid Models (simplified)
struct PlaidAccount: Identifiable, Codable {
    /// Unique identifier for the account
    let id: String
    /// The name of the account, as given by the user or institution
    let name: String
    /// The type of account (e.g., depository, credit, loan)
    let type: String
    /// The more specific subtype of the account (e.g., checking, savings, credit card)
    let subtype: String
    /// Last few digits of the account number, if available, used for display purposes
    let mask: String?
    /// The current balance of the account
    let current: Double
    /// The available balance for spending, if available
    let available: Double?
    /// The credit or spending limit on the account, if applicable
    let limit: Double?
    
    /// Get-only property returning a percentage (e.g., 45.0)
    var utilizationPercentage: Int? {
        guard let limit = limit else { return nil }
        
        return Int((current / limit) * 100.rounded())
    }
    
    var getSubtype: String {
        return subtype.capitalized
    }
}
