import Foundation

struct BankAccount: Identifiable, Codable {
    var id = UUID()
    let name: String
    let type: String
    let balance: Double
}
