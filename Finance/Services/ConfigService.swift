//
//  ConfigService.swift
//  Finance
//
//  Created by David Ott on 12/25/25.
//
import Foundation

class ConfigService {
    
    struct AppConfig: Decodable {
        let PLAID_ENV: String
        let API_BASE_URL: String
        let FEATURE_MANUAL_ACCOUNTS: Bool
    }
    
    init() {
        
    }
    
    func getConfig() -> AppConfig {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let config = try? PropertyListDecoder().decode(AppConfig.self, from: data)
        else {
            fatalError("Missing or invalid Config.plist")
        }
        
        return config
    }
}
