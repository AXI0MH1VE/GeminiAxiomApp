import Foundation
import Combine

class AuthenticationManager {
    static let shared = AuthenticationManager()

    private init() {}

    var isAuthenticated: Bool {
        do {
            let authConfig = GeminiAuthConfig()
            try authConfig.loadFromKeychain()
            return !authConfig.apiKey.isEmpty && !authConfig.apiSecret.isEmpty
        } catch {
            return false
        }
    }

    func authenticate(apiKey: String, apiSecret: String) throws {
        let authConfig = GeminiAuthConfig(apiKey: apiKey, apiSecret: apiSecret)
        try authConfig.saveToKeychain()
    }

    func logout() throws {
        let keychain = KeychainManager.shared
        try keychain.delete(key: AppConfig.shared.keychain.apiKeyKey)
        try keychain.delete(key: AppConfig.shared.keychain.apiSecretKey)
        try keychain.delete(key: AppConfig.shared.keychain.accessTokenKey)
        try keychain.delete(key: AppConfig.shared.keychain.refreshTokenKey)
    }

    func refreshAuthentication() -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            // Implement OAuth refresh logic here if needed
            promise(.success(()))
        }.eraseToAnyPublisher()
    }
}
