import Foundation

// MARK: - Market Data Models

struct GeminiTicker: Codable {
    let bid: String
    let ask: String
    let volume: [String: String]
    let last: String

    enum CodingKeys: String, CodingKey {
        case bid
        case ask
        case volume
        case last
    }
}

struct GeminiOrderBook: Codable {
    let bids: [[String]] // [[price, amount, timestamp]]
    let asks: [[String]] // [[price, amount, timestamp]]
}

struct GeminiTrade: Codable {
    let timestamp: Int64
    let timestampms: Int64
    let tid: Int64
    let price: String
    let amount: String
    let exchange: String
    let type: String
    let broken: Bool?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Int64.self, forKey: .timestamp)
        timestampms = try container.decode(Int64.self, forKey: .timestampms)
        tid = try container.decode(Int64.self, forKey: .tid)
        price = try container.decode(String.self, forKey: .price)
        amount = try container.decode(String.self, forKey: .amount)
        exchange = try container.decode(String.self, forKey: .exchange)
        type = try container.decode(String.self, forKey: .type)
        broken = try container.decodeIfPresent(Bool.self, forKey: .broken)
    }
}

// MARK: - Order Models

struct GeminiOrder: Codable {
    let order_id: String
    let symbol: String
    let price: String
    let avg_execution_price: String
    let side: String
    let type: String
    let timestamp: String
    let timestampms: Int64
    let is_live: Bool
    let is_cancelled: Bool
    let is_hidden: Bool
    let was_forced: Bool
    let executed_amount: String
    let remaining_amount: String
    let original_amount: String
    let options: [String]?
}

// MARK: - Balance Models

struct GeminiBalance: Codable {
    let currency: String
    let amount: String
    let available: String
    let availableForWithdrawal: String?
}

// MARK: - Error Models

struct GeminiError: Codable, Error {
    let reason: String
    let result: String
}

// MARK: - Address Models

struct GeminiAddress: Codable {
    let address: String
    let label: String
    let timestamp: Int64
}

// MARK: - Account Models

struct GeminiAccount: Codable {
    let account: String
    let name: String
    let type: String
    let created: Int64
    let verified: Bool
    let key: String
}
