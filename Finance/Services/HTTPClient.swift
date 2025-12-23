import Foundation

class HTTPClient {
    func get<T: Decodable>(url: URL) async throws -> T {
        return;
    }
    
    func post<T: Decodable>(url: URL, body: Encodable) async throws -> T {
        return;
    }
}
