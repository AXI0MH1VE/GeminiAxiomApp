import Foundation
import Combine

protocol WebSocketDelegate: AnyObject {
    func websocketDidConnect()
    func websocketDidDisconnect(error: Error?)
    func websocketDidReceiveMessage(_ message: [String: Any])
}

class WebSocketManager: NSObject {
    static let shared = WebSocketManager()

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession
    private var pingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    weak var delegate: WebSocketDelegate?

    override init() {
        self.session = URLSession(configuration: .default, delegate: CertificatePinning.shared, delegateQueue: nil)
        super.init()
    }

    func connect() {
        let url = URL(string: AppConfig.shared.environment.websocketURL)!
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()

        receiveMessage()
        startPing()
        delegate?.websocketDidConnect()
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        delegate?.websocketDidDisconnect(error: nil)
    }

    func send(message: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: message, options: [])
            let string = String(data: data, encoding: .utf8)!
            webSocket?.send(.string(string)) { error in
                if let error = error {
                    print("WebSocket send error: \(error)")
                }
            }
        } catch {
            print("Error encoding message: \(error)")
        }
    }

    func subscribe(to symbols: [String], for type: SubscriptionType) {
        let channels = symbols.map { symbol -> [String: Any] in
            [
                "type": "subscribe",
                "product_ids": [symbol],
                "channels": [type.rawValue]
            ]
        }

        for channel in channels {
            send(message: channel)
        }
    }

    func unsubscribe(from symbols: [String], for type: SubscriptionType) {
        let channels = symbols.map { symbol -> [String: Any] in
            [
                "type": "unsubscribe",
                "product_ids": [symbol],
                "channels": [type.rawValue]
            ]
        }

        for channel in channels {
            send(message: channel)
        }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                self.delegate?.websocketDidDisconnect(error: error)
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        self.delegate?.websocketDidReceiveMessage(json)
                    }
                case .data(let data):
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        self.delegate?.websocketDidReceiveMessage(json)
                    }
                @unknown default:
                    break
                }

                // Continue receiving messages
                self.receiveMessage()
            }
        }
    }

    private func startPing() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.webSocket?.sendPing { error in
                if let error = error {
                    print("Ping failed: \(error)")
                    self?.delegate?.websocketDidDisconnect(error: error)
                }
            }
        }
    }

    enum SubscriptionType: String {
        case ticker = "ticker"
        case trades = "matches"
        case orderBook = "level2"
    }
}

// MARK: - Market Data WebSocket Handler

class MarketDataWebSocketHandler: WebSocketDelegate {
    private let viewModel: MarketDataViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: MarketDataViewModel) {
        self.viewModel = viewModel
    }

    func websocketDidConnect() {
        print("WebSocket connected")
        // Subscribe to common symbols
        WebSocketManager.shared.subscribe(to: ["btcusd", "ethusd"], for: .ticker)
        WebSocketManager.shared.subscribe(to: ["btcusd", "ethusd"], for: .orderBook)
        WebSocketManager.shared.subscribe(to: ["btcusd", "ethusd"], for: .trades)
    }

    func websocketDidDisconnect(error: Error?) {
        if let error = error {
            print("WebSocket disconnected with error: \(error)")
        } else {
            print("WebSocket disconnected")
        }
    }

    func websocketDidReceiveMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "ticker":
            handleTickerMessage(message)
        case "l2update":
            handleOrderBookUpdate(message)
        case "match":
            handleTradeMessage(message)
        default:
            break
        }
    }

    private func handleTickerMessage(_ message: [String: Any]) {
        guard let productId = message["product_id"] as? String,
              let bidString = message["best_bid"] as? String,
              let askString = message["best_ask"] as? String,
              let lastString = message["price"] as? String else { return }

        let volume = ["today": message["volume_24h"] as? String ?? "0"]
        let ticker = GeminiTicker(bid: bidString, ask: askString, volume: volume, last: lastString)

        viewModel.updateTicker(symbol: productId, ticker: ticker)
    }

    private func handleOrderBookUpdate(_ message: [String: Any]) {
        // Order book updates require maintaining state
        // This is a simplified version
        print("Order book update: \(message)")
    }

    private func handleTradeMessage(_ message: [String: Any]) {
        guard let productId = message["product_id"] as? String,
              let tradeId = message["trade_id"] as? Int,
              let price = message["price"] as? String,
              let size = message["size"] as? String,
              let time = message["time"] as? String else { return }

        let trade = GeminiTrade(
            timestamp: Int64(Date().timeIntervalSince1970),
            timestampms: Int64(Date().timeIntervalSince1970 * 1000),
            tid: Int64(tradeId),
            price: price,
            amount: size,
            exchange: "gemini",
            type: message["side"] as? String ?? "unknown",
            broken: nil
        )

        // Update recent trades
        DispatchQueue.main.async {
            self.viewModel.recentTrades.insert(trade, at: 0)
            if self.viewModel.recentTrades.count > 50 {
                self.viewModel.recentTrades = Array(self.viewModel.recentTrades.prefix(50))
            }
        }
    }
}
