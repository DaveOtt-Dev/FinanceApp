//
//  PlaidInfoView.swift
//  Finance
//
//  Created by David Ott on 12/24/25.
//
import SwiftUI
import LinkKit

struct AddAccountsView: View {
    @State private var _showPlaidLink = false
    
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
            // .overlay(Divider(), alignment: .bottom)
        }
        
        ScrollView {
            VStack(spacing: 16) {
                Button(action: {
                    _showPlaidLink = true
                }) {
                    Label("Link External Account", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.glass)
                .controlSize(.regular)
                .sheet(isPresented: $_showPlaidLink) {
                    PlaidLinkViewControllerWrapper()
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
    }
}
