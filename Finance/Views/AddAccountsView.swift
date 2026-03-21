//
//  PlaidInfoView.swift
//  Finance
//
//  Created by David Ott on 12/24/25.
//
import SwiftUI
import LinkKit

struct AddAccountsView: View {
    @StateObject private var plaidService = PlaidService()
    @State private var showPlaidLink = false
    @State private var showErrorAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Account")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial)
        }
        
        ScrollView {
            VStack(spacing: 16) {
                Button(action: {
                    showPlaidLink = true
                }) {
                    if plaidService.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Label("Link External Account", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .buttonStyle(.glass)
                .controlSize(.regular)
                .disabled(plaidService.isLoading)
                .sheet(isPresented: $showPlaidLink) {
                    PlaidLinkViewControllerWrapper(plaidService: plaidService)
                }
                
                Button(action: {
                    print("Add Manual Account Clicked")
                }) {
                    Label("Add Manual Account", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.glass)
                .controlSize(.regular)
            }
            .padding()
            
            Spacer()
        }
        .onChange(of: plaidService.error) { oldValue, newValue in
            if newValue != nil {
                showErrorAlert = true
            }
        }
        .alert("Linking Failed", isPresented: $showErrorAlert) {
            Button("OK") {
                plaidService.reset()
            }
        } message: {
            Text(plaidService.error?.localizedDescription ?? "An unknown error occurred")
        }
    }
}
