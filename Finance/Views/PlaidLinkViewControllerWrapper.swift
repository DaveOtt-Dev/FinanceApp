//
//  PlaidLinkViewControllerWrapper.swift
//  Finance
//
//  Created by David Ott on 12/24/25.
//
import SwiftUI
import LinkKit

/// PlaidLinkViewControllerWrapper is a UIViewControllerRepresentable that wraps
/// the Plaid Link flow in a way that can be presented from SwiftUI.
///
/// This wrapper coordinates with PlaidService to:
/// 1. Obtain a link_token from PlaidAPI
/// 2. Present the Plaid Link UI
/// 3. Handle the success/cancel/error callbacks
/// 4. Return the public_token to be exchanged by PlaidService
///
/// **Note**: This view controller handles UI presentation only. Token exchange
/// and account fetching are managed by PlaidService.
struct PlaidLinkViewControllerWrapper: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var plaidService: PlaidService
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        // Fetch link token asynchronously
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            getLinkToken { linkToken in
                presentPlaidLink(with: linkToken, from: viewController)
            }
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    /// Fetches the link_token from the backend via PlaidAPI.
    private func getLinkToken(completion: @escaping (String) -> Void) {
        Task {
            do {
                let token = try await PlaidAPI.shared.createLinkToken()
                completion(token)
            } catch {
                plaidService.error = error as? PlaidAPIError ?? PlaidAPIError.networkError(error)
                dismiss()
            }
        }
    }
    
    /// Presents the Plaid Link UI with the provided link_token.
    private func presentPlaidLink(with linkToken: String, from viewController: UIViewController) {
        guard !linkToken.isEmpty else {
            plaidService.error = PlaidAPIError.invalidLinkToken
            dismiss()
            return
        }
        
        // Configure Plaid Link with the link token
        let linkConfiguration = LinkTokenConfiguration(token: linkToken) { success in
            // On successful Plaid Link authentication, the public_token is provided
            Task {
                await plaidService.linkAccount(
                    presentingViewController: viewController
                )
            }
            dismiss()
        }
        
        // Configure handlers for cancel and error events
        linkConfiguration.onCancel = {
            dismiss()
        }
        
        linkConfiguration.onError = { error in
            plaidService.error = PlaidAPIError.networkError(error)
            dismiss()
        }
        
        // Create and present the Plaid handler
        let result = Plaid.create(linkConfiguration)
        
        switch result {
        case .success(let handler):
            DispatchQueue.main.async {
                handler.open(presentUsing: .viewController(viewController))
            }
        case .failure(let error):
            plaidService.error = PlaidAPIError.networkError(error)
            dismiss()
        }
    }
}
