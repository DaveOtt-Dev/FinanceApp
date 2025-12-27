//
//  LoadingView.swift
//  Finance
//
//  Created by David Ott on 12/24/25.
//
import SwiftUI

struct LoadingView: View {
    var body: some View {
        Spacer()
        
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .padding()
        
        Spacer()
    }
}
