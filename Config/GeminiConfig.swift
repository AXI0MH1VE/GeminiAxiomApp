import Foundation

struct GeminiAuthConfig {
    var apiKey: String = ""
    var apiSecret: String = ""
    var clientId: String = ""
    var clientSecret: String = ""
    var useOAuth: Bool = false
    var oauthAccessToken: String = ""
    var oauthRefreshToken: String = ""

    mutating func loadFromKeychain() throws {
        let keychain = KeychainManager.shared
        self.apiKey = try keychain.retrieve(key: AppConfig.shared.keychain.apiKeyKey) ?? ""
        self.apiSecret = try keychain.retrieve(key: AppConfig.shared.keychain.apiSecretKey) ?? ""
        self.oauthAccessToken = try keychain.retrieve(key: AppConfig.shared.keychain.accessTokenKey) ?? ""
        self.oauthRefreshToken = try keychain.retrieve(key: AppConfig.shared.keychain.refreshTokenKey) ?? ""
    }

    func saveToKeychain() throws {
        let keychain = KeychainManager.shared
        try keychain.store(key: AppConfig.shared.keychain.apiKeyKey, value: apiKey)
        try keychain.store(key: AppConfig.shared.keychain.apiSecretKey, value: apiSecret)
        try keychain.store(key: AppConfig.shared.keychain.accessTokenKey, value: oauthAccessToken)
        try keychain.store(key: AppConfig.shared.keychain.refreshTokenKey, value: oauthRefreshToken)
    }
}

struct GeminiEndpoints {
    static let ticker = "/v1/pubticker"
    static let orderBook = "/v1/book"
    static let trades = "/v1/trades"
    static let orderNew = "/v1/order/new"
    static let orderCancel = "/v1/order/cancel"
    static let orderStatus = "/v1/order/status"
    static let balances = "/v1/balances"
    static let addresses = "/v1/addresses"
    static let newAddress = "/v1/deposit/{network}/newAddress"
    static let withdraw = "/v1/withdraw/{currency}"
    static let account = "/v1/account"
    static let accountCreate = "/v1/account/create"
    static let accountList = "/v1/account/list"
}

struct GeminiRateLimitConfig {
    let publicRateLimit = 120              // per minute
    let privateRateLimit = 600             // per minute
    let sandboxPublicDelay: TimeInterval = 0.5
    let sandboxPrivateDelay: TimeInterval = 0.1
}
