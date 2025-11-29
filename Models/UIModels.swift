import Foundation
import SwiftUI

// MARK: - View Models

class GeminiAxiomViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var balances: [GeminiBalance] = []
    @Published var openOrders: [GeminiOrder] = []
    @Published var marketData: MarketDataViewModel = MarketDataViewModel()
    @Published var authenticationRequired = true

    func clearError() {
        errorMessage = nil
    }
}

class MarketDataViewModel: ObservableObject {
    @Published var tickers: [String: GeminiTicker] = [:]
    @Published var selectedSymbol = "btcusd"
    @Published var orderBooks: [String: GeminiOrderBook] = [:]
    @Published var recentTrades: [GeminiTrade] = []

    func updateTicker(symbol: String, ticker: GeminiTicker) {
        DispatchQueue.main.async {
            self.tickers[symbol] = ticker
        }
    }

    func updateOrderBook(symbol: String, orderBook: GeminiOrderBook) {
        DispatchQueue.main.async {
            self.orderBooks[symbol] = orderBook
        }
    }
}

class TradingViewModel: ObservableObject {
    @Published var symbol = "btcusd"
    @Published var orderType: OrderType = .limit
    @Published var side: OrderSide = .buy
    @Published var amount = ""
    @Published var price = ""
    @Published var total = 0.0

    enum OrderType: String, CaseIterable {
        case market = "Market"
        case limit = "Limit"
        case stopLoss = "Stop Loss"
    }

    enum OrderSide: String {
        case buy = "Buy"
        case sell = "Sell"

        var color: Color {
            switch self {
            case .buy: return .green
            case .sell: return .red
            }
        }
    }

    func calculateTotal() {
        if let amount = Double(amount), let price = Double(price) {
            total = amount * price
        } else {
            total = 0.0
        }
    }
}

class WalletViewModel: ObservableObject {
    @Published var balances: [GeminiBalance] = []
    @Published var totalValue: Double = 0.0
    @Published var selectedCurrency = "USD"

    func updateBalances(_ balances: [GeminiBalance]) {
        self.balances = balances
        // Calculate total value (would require price feeds)
        self.totalValue = balances.reduce(0.0) { total, balance in
            total + (Double(balance.amount) ?? 0.0)
        }
    }
}

class BARKViewModel: ObservableObject {
    @Published var directives: [BARKDirective] = []
    @Published var auditEntries: [BARKAuditEntry] = []
    @Published var isProcessingDirective = false

    func addDirective(_ directive: BARKDirective) {
        DispatchQueue.main.async {
            self.directives.insert(directive, at: 0)
        }
    }

    func addAuditEntry(_ entry: BARKAuditEntry) {
        DispatchQueue.main.async {
            self.auditEntries.insert(entry, at: 0)

            // Limit audit entries to prevent memory issues
            if self.auditEntries.count > 1000 {
                self.auditEntries = Array(self.auditEntries.prefix(1000))
            }
        }
    }
}

// MARK: - UI Models

struct SymbolInfo: Identifiable {
    let id = UUID()
    let symbol: String
    let baseCurrency: String
    let quoteCurrency: String
    let displayName: String

    static let commonSymbols = [
        SymbolInfo(symbol: "btcusd", baseCurrency: "BTC", quoteCurrency: "USD", displayName: "BTC/USD"),
        SymbolInfo(symbol: "ethusd", baseCurrency: "ETH", quoteCurrency: "USD", displayName: "ETH/USD"),
        SymbolInfo(symbol: "btcusd", baseCurrency: "BTC", quoteCurrency: "USD", displayName: "BTC/USD"),
        SymbolInfo(symbol: "ethusd", baseCurrency: "ETH", quoteCurrency: "USD", displayName: "ETH/USD"),
        SymbolInfo(symbol: "ltcusd", baseCurrency: "LTC", quoteCurrency: "USD", displayName: "LTC/USD"),
        SymbolInfo(symbol: "zecusd", baseCurrency: "ZEC", quoteCurrency: "USD", displayName: "ZEC/USD")
    ]
}

struct CurrencyInfo {
    let symbol: String
    let name: String
    let type: String  // crypto, fiat

    static let all = [
        "BTC": CurrencyInfo(symbol: "BTC", name: "Bitcoin", type: "crypto"),
        "ETH": CurrencyInfo(symbol: "ETH", name: "Ethereum", type: "crypto"),
        "LTC": CurrencyInfo(symbol: "LTC", name: "Litecoin", type: "crypto"),
        "ZEC": CurrencyInfo(symbol: "ZEC", name: "Zcash", type: "crypto"),
        "USD": CurrencyInfo(symbol: "USD", name: "US Dollar", type: "fiat")
    ]
}
