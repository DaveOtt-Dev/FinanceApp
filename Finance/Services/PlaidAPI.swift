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

    struct LinkTokenRequest: Codable {
        let client_id: String
        let secret: String
        let client_name: String
        let language: String
        let country_codes: [String]
        let user: [String: String]
        let products: [String]
    }

    func createLinkToken() async throws -> String {
        let url = URL(string: "https://sandbox.plaid.com/link/token/create")!

        let body = LinkTokenRequest(
            client_id: "<client_id>",
            secret: "<secret>",
            client_name: "FinanceApp",
            language: "en",
            country_codes: ["US"],
            user: ["client_user_id": UUID().uuidString],
            products: ["auth", "transactions"]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        return json["link_token"] as! String
    }
    
    /// Simulated endpoint for retrieving accounts
    func getAccounts() async throws -> [PlaidAccount] {
        try await withCheckedThrowingContinuation { continuation in
            // Existing dummy implementation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let accounts: [PlaidAccount] = [
                    PlaidAccount(id: "acc_1", name: "BECU Checking", type: "depository", subtype: "checking", mask: "1234", current: 1200.50, available: 1200.50, limit: nil),
                    PlaidAccount(id: "acc_2", name: "BECU Savings", type: "depository", subtype: "savings", mask: "5678", current: 5000.00, available: 5000.00, limit: nil),
                    PlaidAccount(id: "acc_3", name: "SoFi Credit Card", type: "credit", subtype: "credit card", mask: "4321", current: 2000.00, available: 800.00, limit: 2800.00)
                ]
                continuation.resume(returning: accounts)
            }
        }
    }
}
