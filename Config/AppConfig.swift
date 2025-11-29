import Foundation

struct AppConfig {
    static let shared = AppConfig()

    // MARK: - Environment
    let environment: Environment = .sandbox
    let isDebugMode = true

    // MARK: - API Configuration
    let apiTimeout: TimeInterval = 30
    let maxRetries: Int = 3
    let retryDelay: TimeInterval = 1.0

    // MARK: - Rate Limits
    let publicRateLimit: Int = 120        // requests/minute
    let privateRateLimit: Int = 600       // requests/minute
    let publicRateInterval: TimeInterval = 60
    let privateRateInterval: TimeInterval = 60

    // MARK: - Security
    let enableCertificatePinning = true
    let enableSSLValidation = true
    let keychain = KeychainConfig()

    enum Environment {
        case production
        case sandbox

        var baseURL: String {
            switch self {
            case .production:
                return "https://api.gemini.com"
            case .sandbox:
                return "https://api.sandbox.gemini.com"
            }
        }

        var exchangeURL: String {
            switch self {
            case .production:
                return "https://exchange.gemini.com"
            case .sandbox:
                return "https://exchange.sandbox.gemini.com"
            }
        }

        var websocketURL: String {
            switch self {
            case .production:
                return "wss://ws.gemini.com/v1"
            case .sandbox:
                return "wss://ws.sandbox.gemini.com/v1"
            }
        }
    }
}

struct KeychainConfig {
    let service = "com.axiomhive.gemini"
    let accessGroup = "group.com.axiomhive"
    let apiKeyKey = "gemini_api_key"
    let apiSecretKey = "gemini_api_secret"
    let accessTokenKey = "gemini_access_token"
    let refreshTokenKey = "gemini_refresh_token"
    let barkPrivateKeyKey = "bark_private_key"
    let barkPublicKeyKey = "bark_public_key"
}
