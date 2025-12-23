//
//  PlaidController.swift
//  Finance
//
//  Created by David Ott on 11/22/25.
//

import Foundation

class PlaidAPIService {
    private let client = HTTPClient()

    func createLinkToken() async throws -> PlaidLinkToken { ... }
    func exchangePublicToken(_ token: String) async throws -> AccessTokenResponse { ... }
    func fetchAccounts(accessToken: String) async throws -> [Account] { ... }
}
