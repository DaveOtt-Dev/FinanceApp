//
//  PlaidAPI.swift
//  Finance
//
//  Created by David Ott on 12/23/25.
//
import Foundation

// MARK: - Plaid API Errors
enum PlaidAPIError: LocalizedError {
    case invalidConfiguration
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse
    case invalidLinkToken
    case tokenExchangeFailed(String)
    case accountsFetchFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Plaid configuration is invalid or missing."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .invalidLinkToken:
            return "Failed to create a link token."
        case .tokenExchangeFailed(let message):
            return "Token exchange failed: \(message)"
        case .accountsFetchFailed(let message):
            return "Failed to fetch accounts: \(message)"
        }
    }
}

// MARK: - Plaid API Layer
/// PlaidAPI is responsible for all Plaid-related network operations.
/// 
/// This class manages the complete Plaid Link flow:
/// 1. Requesting a link_token from the backend
/// 2. Launching Plaid Link with that token
/// 3. Handling success/cancel/error callbacks
/// 4. Exchanging the public_token with the backend
/// 5. Fetching account details after successful token exchange
///
/// **Security Note**: This class never stores or exposes Plaid secrets or access tokens.
/// All sensitive operations (secret validation, item access token management) are performed
/// on the backend only. The iOS app only handles public_token exchange and account retrieval.
///
/// **Usage**:
/// ```
/// let linkToken = try await PlaidAPI.shared.createLinkToken()
/// let publicToken = try await PlaidAPI.shared.openPlaidLink(linkToken: linkToken)
/// try await PlaidAPI.shared.exchangePublicToken(publicToken: publicToken)
/// let accounts = try await PlaidAPI.shared.fetchAccounts()
/// ```
class PlaidAPI {
    static let shared = PlaidAPI()
    
    private let configService = ConfigService()
    
    private init() {}

    // MARK: - Models
    
    /// Request body for creating a link token on the backend.
    struct LinkTokenRequest: Codable {
        /// A unique identifier for this user in your system
        let clientUserId: String
        
        enum CodingKeys: String, CodingKey {
            case clientUserId = "client_user_id"
        }
    }
    
    /// Response body for the link token creation endpoint.
    struct LinkTokenResponse: Codable {
        let linkToken: String
        let expiration: String?
        
        enum CodingKeys: String, CodingKey {
            case linkToken = "link_token"
            case expiration
        }
    }
    
    /// Request body for exchanging a public_token.
    struct TokenExchangeRequest: Codable {
        let publicToken: String
        
        enum CodingKeys: String, CodingKey {
            case publicToken = "public_token"
        }
    }
    
    /// Response body for the token exchange endpoint.
    struct TokenExchangeResponse: Codable {
        let itemId: String
        let accessToken: String?
        
        enum CodingKeys: String, CodingKey {
            case itemId = "item_id"
            case accessToken = "access_token"
        }
    }
    
    /// Response body for the accounts fetch endpoint.
    struct AccountsResponse: Codable {
        let accounts: [PlaidAccount]
        
        enum CodingKeys: String, CodingKey {
            case accounts
        }
    }
    
    // MARK: - Public Methods
    
    /// Requests a link_token from the backend to initialize the Plaid Link flow.
    ///
    /// This method makes a network request to the backend endpoint `/item/link_token/create`.
    /// The backend uses its Plaid secret key to generate a link_token via Plaid's API.
    /// The link_token is then returned to the app and used to launch Plaid Link.
    ///
    /// - Returns: A link_token string that can be used with Plaid Link
    /// - Throws: PlaidAPIError if the request fails or the response is invalid
    ///
    /// **Note**: The Plaid client_id and secret are never exposed to the app.
    /// The backend validates these credentials and securely creates the token.
    func createLinkToken() async throws -> String {
        guard let apiBaseURL = configService.getConfig().API_BASE_URL else {
            throw PlaidAPIError.invalidConfiguration
        }
        
        guard let url = URL(string: "\(apiBaseURL)/item/link_token/create") else {
            throw PlaidAPIError.invalidConfiguration
        }
        
        let request = LinkTokenRequest(
            clientUserId: UUID().uuidString
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw PlaidAPIError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            let response = try decoder.decode(LinkTokenResponse.self, from: data)
            
            return response.linkToken
        } catch let error as PlaidAPIError {
            throw error
        } catch let error as DecodingError {
            throw PlaidAPIError.decodingError(error)
        } catch {
            throw PlaidAPIError.networkError(error)
        }
    }
    
    /// Launches the Plaid Link UI with the provided link_token.
    ///
    /// This method is typically called after receiving a link_token from `createLinkToken()`.
    /// It presents the Plaid Link flow to the user, allowing them to authenticate with their
    /// financial institution. The method uses the LinkKit SDK to display the UI.
    ///
    /// - Parameter linkToken: The link_token obtained from `createLinkToken()`
    /// - Parameter presentingViewController: The view controller that will present Plaid Link
    /// - Parameter onSuccess: Closure called with the public_token upon successful authentication
    /// - Parameter onCancel: Closure called when the user cancels the Plaid Link flow
    /// - Parameter onError: Closure called if an error occurs during the flow
    ///
    /// **Note**: This method handles the presentation of Plaid's UI. The actual token
    /// exchange should be performed separately using `exchangePublicToken()`.
    func openPlaidLink(
        linkToken: String,
        presentingViewController: UIViewController,
        onSuccess: @escaping (String) -> Void,
        onCancel: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard !linkToken.isEmpty else {
            onError(PlaidAPIError.invalidLinkToken)
            return
        }
        
        // Create the Plaid Link configuration with the link token
        let linkConfiguration = LinkTokenConfiguration(token: linkToken) { success in
            // On successful Plaid Link authentication, we receive a public_token
            onSuccess(success.publicToken)
        }
        
        // Configure handlers for cancel and error events
        linkConfiguration.onCancel = onCancel
        linkConfiguration.onError = { error in
            onError(PlaidAPIError.networkError(error))
        }
        
        // Create the Plaid handler and present the Link UI
        let result = Plaid.create(linkConfiguration)
        
        switch result {
        case .success(let handler):
            DispatchQueue.main.async {
                handler.open(presentUsing: .viewController(presentingViewController))
            }
        case .failure(let error):
            onError(PlaidAPIError.networkError(error))
        }
    }
    
    /// Exchanges a public_token (from Plaid Link) for an access_token on the backend.
    ///
    /// After the user successfully authenticates through Plaid Link, the Link flow returns
    /// a public_token. This method sends that public_token to the backend endpoint
    /// `/item/public_token/exchange`, where it is exchanged for an access_token.
    ///
    /// The backend uses its Plaid secret key to perform the exchange securely.
    /// The access_token is stored on the backend and never exposed to the iOS app.
    ///
    /// - Parameter publicToken: The public_token returned by Plaid Link
    /// - Returns: The item_id of the linked financial institution
    /// - Throws: PlaidAPIError if the exchange fails
    ///
    /// **Security Note**: The access_token is handled exclusively by the backend.
    /// The iOS app never receives or stores it.
    func exchangePublicToken(publicToken: String) async throws -> String {
        guard let apiBaseURL = configService.getConfig().API_BASE_URL else {
            throw PlaidAPIError.invalidConfiguration
        }
        
        guard let url = URL(string: "\(apiBaseURL)/item/public_token/exchange") else {
            throw PlaidAPIError.invalidConfiguration
        }
        
        let request = TokenExchangeRequest(publicToken: publicToken)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw PlaidAPIError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            let exchangeResponse = try decoder.decode(TokenExchangeResponse.self, from: data)
            
            return exchangeResponse.itemId
        } catch let error as PlaidAPIError {
            throw error
        } catch let error as DecodingError {
            throw PlaidAPIError.decodingError(error)
        } catch let error as URLError {
            throw PlaidAPIError.networkError(error)
        } catch {
            throw PlaidAPIError.tokenExchangeFailed(error.localizedDescription)
        }
    }
    
    /// Fetches the linked accounts from the backend after successful token exchange.
    ///
    /// This method calls the backend endpoint `/accounts/get` to retrieve account
    /// details for the currently linked financial institution. The backend uses the
    /// stored access_token to fetch this information from Plaid.
    ///
    /// - Returns: An array of PlaidAccount objects representing the user's accounts
    /// - Throws: PlaidAPIError if the fetch fails
    ///
    /// **Note**: This method should be called after `exchangePublicToken()` has
    /// completed successfully.
    func fetchAccounts() async throws -> [PlaidAccount] {
        guard let apiBaseURL = configService.getConfig().API_BASE_URL else {
            throw PlaidAPIError.invalidConfiguration
        }
        
        guard let url = URL(string: "\(apiBaseURL)/accounts/get") else {
            throw PlaidAPIError.invalidConfiguration
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw PlaidAPIError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            let accountsResponse = try decoder.decode(AccountsResponse.self, from: data)
            
            return accountsResponse.accounts
        } catch let error as PlaidAPIError {
            throw error
        } catch let error as DecodingError {
            throw PlaidAPIError.decodingError(error)
        } catch let error as URLError {
            throw PlaidAPIError.networkError(error)
        } catch {
            throw PlaidAPIError.accountsFetchFailed(error.localizedDescription)
        }
    }
    
    /// Simulated endpoint for retrieving accounts (fallback for testing).
    ///
    /// This method provides mock account data for testing and development purposes.
    /// In production, use `fetchAccounts()` instead.
    func getAccountsMock() async throws -> [PlaidAccount] {
        try await withCheckedThrowingContinuation { continuation in
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
