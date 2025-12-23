//
//  FinanceApp.swift
//  Finance
//
//  Created by David Ott on 11/22/25.
//

import SwiftUI

@main
struct FinanceApp: App {
    @State private var accounts: [PlaidAccount] = []
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
