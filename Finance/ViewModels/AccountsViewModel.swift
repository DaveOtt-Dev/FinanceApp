import Foundation
internal import Combine

@MainActor
class AccountsViewModel: ObservableObject {
    var objectWillChange: ObservableObjectPublisher
    
    init() {
        
    }
    
    @Published var accounts: [Account] = []
    @Published var totalBalance: Double = 0

    func loadAccounts() async {
        
    }
}
