//
//  PlaidAPI.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//
import Foundation

// MARK: - Plaid API Layer
class PlaidAPI {
    static let shared = PlaidAPI()
    
    private init() {}
    
    /// Simulated endpoint for retrieving accounts
    func getAccounts() async throws -> [PlaidAccount] {
        try await withCheckedThrowingContinuation { continuation in
            // Existing dummy implementation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let accounts: [PlaidAccount] = [
                    PlaidAccount(id: "acc_1", name: "Checking", type: "depository", subtype: "checking", mask: "1234", current: 1200.50, available: 1200.50, limit: nil),
                    PlaidAccount(id: "acc_2", name: "Savings", type: "depository", subtype: "savings", mask: "5678", current: 5000.00, available: 5000.00, limit: nil),
                    PlaidAccount(id: "acc_3", name: "Credit Card", type: "credit", subtype: "credit card", mask: "4321", current: 800.00, available: 2000.00, limit: 2800.00)
                ]
                continuation.resume(returning: accounts)
            }
        }
    }
}
