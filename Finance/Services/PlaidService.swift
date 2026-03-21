//
//  PlaidService.swift
//  Finance
//
//  Created by David Ott on 02/27/26.
//
import Foundation
import SwiftUI

/// PlaidService is a view model that manages the Plaid Link flow in SwiftUI.
///
/// This class provides a simple, reusable interface for triggering the Plaid Link flow
/// and handling its results. It abstracts away the complexity of managing tokens, making
/// API calls, and handling errors.
///
/// **Usage in a SwiftUI View**:
/// ```swift
/// @StateObject var plaidService = PlaidService()
///
/// Button("Link Account") {
///     Task {
///         await plaidService.linkAccount(presentingViewController: window.rootViewController!)
///     }
/// }
/// .alert("Error", isPresented: .constant(plaidService.error != nil)) {
///     Button("OK") { plaidService.error = nil }
/// } message: {
///     Text(plaidService.error?.localizedDescription ?? "")
/// }
/// ```
///
/// **States**:
/// - `.idle`: No operation in progress
/// - `.requestingToken`: Fetching link_token from backend
/// - `.linkingAccount`: User is interacting with Plaid Link
/// - `.exchangingToken`: Exchanging public_token for access_token
/// - `.fetchingAccounts`: Retrieving account details from backend
/// - `.success`: Account linking completed successfully
///
@MainActor
class PlaidService: NSObject, ObservableObject {
    
    /// Represents the current state of the Plaid Link flow.
    enum LinkState {
        case idle
        case requestingToken
        case linkingAccount
        case exchangingToken
        case fetchingAccounts
        case success
    }
    
    @Published var state: LinkState = .idle
    @Published var error: PlaidAPIError? = nil
    @Published var linkedAccounts: [PlaidAccount] = []
    @Published var isLoading: Bool { state != .idle && state != .success }
    
    private let plaidAPI = PlaidAPI.shared
    
    override init() {
        super.init()
    }
    
    /// Initiates the Plaid Link flow.
    ///
    /// This method handles the entire flow:
    /// 1. Requests a link_token from the backend
    /// 2. Launches the Plaid Link UI
    /// 3. Exchanges the public_token on success
    /// 4. Fetches the newly linked accounts
    ///
    /// - Parameter presentingViewController: The view controller that will present Plaid Link
    /// - Returns: The linked accounts if successful, or throws an error
    ///
    /// **Error Handling**: Errors are published to the `error` property and can be
    /// displayed to the user via alerts or other UI elements.
    func linkAccount(presentingViewController: UIViewController) async {
        do {
            // Step 1: Request link token
            state = .requestingToken
            let linkToken = try await plaidAPI.createLinkToken()
            
            // Step 2: Present Plaid Link
            state = .linkingAccount
            let publicToken = try await withCheckedThrowingContinuation { continuation in
                plaidAPI.openPlaidLink(
                    linkToken: linkToken,
                    presentingViewController: presentingViewController,
                    onSuccess: { publicToken in
                        continuation.resume(returning: publicToken)
                    },
                    onCancel: {
                        continuation.resume(throwing: PlaidAPIError.invalidLinkToken)
                    },
                    onError: { error in
                        continuation.resume(throwing: error)
                    }
                )
            }
            
            // Step 3: Exchange public token
            state = .exchangingToken
            _ = try await plaidAPI.exchangePublicToken(publicToken: publicToken)
            
            // Step 4: Fetch accounts
            state = .fetchingAccounts
            linkedAccounts = try await plaidAPI.fetchAccounts()
            
            state = .success
            error = nil
        } catch let error as PlaidAPIError {
            state = .idle
            self.error = error
        } catch {
            state = .idle
            self.error = PlaidAPIError.networkError(error)
        }
    }
    
    /// Resets the service state and clears any error messages.
    ///
    /// Call this method to dismiss error alerts or reset the service
    /// for another linking attempt.
    func reset() {
        state = .idle
        error = nil
    }
}
