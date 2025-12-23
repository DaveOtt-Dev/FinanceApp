struct Account: Identifiable, Codable {
    let id: String
    let name: String
    let type: String
    let subtype: String?
    let available: Double?
    let current: Double?
}
