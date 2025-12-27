//
//  AccountInfoView.swift
//  Finance
//
//  Created by David Ott on 12/25/25.
//
import SwiftUI

struct BankAccountInfoView: View {
    @State var _account: PlaidAccount
    
    init(account: PlaidAccount) {
        _account = account
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Account Info")
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
            VStack(alignment: .leading, spacing: 4) {
                Text(_account.name)
                    .font(Font.title)
                    .bold()
                
                Text("Balance")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(_account.current.formattedAsCurrency())
                    .font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}
