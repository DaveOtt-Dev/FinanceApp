//
//  PlaidLinkViewControllerWrapper.swift
//  Finance
//
//  Created by David Ott on 12/24/25.
//
import SwiftUI
import LinkKit

struct PlaidLinkViewControllerWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController() // placeholder
        
        let linkToken = getLinkToken() // get this from your server
        let configuration = LinkTokenConfiguration(token: linkToken) { success in
            print("Successfully linked account:", success)
        }
        
        // Create the Plaid handler
        let result = Plaid.create(configuration)
        
        switch result {
        case .success(let handler):
            // Present Plaid Link immediately
            DispatchQueue.main.async {
                handler.open(presentUsing: .viewController(viewController))
            }
        case .failure(let error):
            print("Failed to create Plaid Link:", error)
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
    
    private func getLinkToken() async -> String {
        return await PlaidAPI.shared.createLinkToken()
    }
}
