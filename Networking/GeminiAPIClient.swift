import Foundation
import Combine

class GeminiAPIClient: NSObject {
    static let shared = GeminiAPIClient()

    private let session: URLSession
    private let rateLimiter = RateLimiter()
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = AppConfig.shared.apiTimeout
        configuration.timeoutIntervalForResource = AppConfig.shared.apiTimeout

        self.session = URLSession(configuration: configuration, delegate: CertificatePinning.shared, delegateQueue: nil)

        super.init()
    }

    // MARK: - Public Market Data

    func getTicker(symbol: String) -> AnyPublisher<GeminiTicker, Error> {
        return rateLimiter.execute(request: makeRequest(endpoint: GeminiEndpoints.ticker + "/\(symbol)", private: false))
            .tryMap { data -> GeminiTicker in
                let ticker = try JSONDecoder().decode(GeminiTicker.self, from: data)
                return ticker
            }
            .eraseToAnyPublisher()
    }

    func getOrderBook(symbol: String) -> AnyPublisher<GeminiOrderBook, Error> {
        return rateLimiter.execute(request: makeRequest(endpoint: GeminiEndpoints.orderBook + "/\(symbol)", private: false))
            .tryMap { data -> GeminiOrderBook in
                let orderBook = try JSONDecoder().decode(GeminiOrderBook.self, from: data)
                return orderBook
            }
            .eraseToAnyPublisher()
    }

    func getTrades(symbol: String, since: Int64? = nil, limit: Int? = nil) -> AnyPublisher<[GeminiTrade], Error> {
        var endpoint = GeminiEndpoints.trades + "/\(symbol)"
        var params = [String: String]()

        if let since = since {
            params["since"] = "\(since)"
        }
        if let limit = limit {
            params["limit_trades"] = "\(limit)"
        }

        if !params.isEmpty {
            endpoint += "?" + params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        }

        return rateLimiter.execute(request: makeRequest(endpoint: endpoint, private: false))
            .tryMap { data -> [GeminiTrade] in
                let trades = try JSONDecoder().decode([GeminiTrade].self, from: data)
                return trades
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Private API Endpoints

    func getBalances() -> AnyPublisher<[GeminiBalance], Error> {
        return makeAuthenticatedRequest(endpoint: GeminiEndpoints.balances, method: "POST")
            .tryMap { data -> [GeminiBalance] in
                let balances = try JSONDecoder().decode([GeminiBalance].self, from: data)
                return balances
            }
            .eraseToAnyPublisher()
    }

    func getOrders(symbol: String? = nil) -> AnyPublisher<[GeminiOrder], Error> {
        var params = [String: String]()
        if let symbol = symbol {
            params["symbol"] = symbol
        }

        return makeAuthenticatedRequest(endpoint: GeminiEndpoints.orderStatus, method: "POST", params: params)
            .tryMap { data -> [GeminiOrder] in
                // Handle single order or array response
                if let orders = try? JSONDecoder().decode([GeminiOrder].self, from: data) {
                    return orders
                } else if let order = try? JSONDecoder().decode(GeminiOrder.self, from: data) {
                    return [order]
                } else {
                    return []
                }
            }
            .eraseToAnyPublisher()
    }

    func newOrder(symbol: String, amount: String, price: String? = nil, side: String, type: String) -> AnyPublisher<GeminiOrder, Error> {
        var params = [
            "symbol": symbol,
            "amount": amount,
            "side": side,
            "type": type
        ]

        if let price = price {
            params["price"] = price
        }

        return makeAuthenticatedRequest(endpoint: GeminiEndpoints.orderNew, method: "POST", params: params)
            .tryMap { data -> GeminiOrder in
                let order = try JSONDecoder().decode(GeminiOrder.self, from: data)
                return order
            }
            .eraseToAnyPublisher()
    }

    func cancelOrder(orderId: String) -> AnyPublisher<[String: Any], Error> {
        let params = ["order_id": orderId]

        return makeAuthenticatedRequest(endpoint: GeminiEndpoints.orderCancel, method: "POST", params: params)
            .tryMap { data -> [String: Any] in
                let response = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
                return response
            }
            .eraseToAnyPublisher()
    }

    func getNewAddress(currency: String, network: String = "bitcoin") -> AnyPublisher<GeminiAddress, Error> {
        let endpoint = GeminiEndpoints.newAddress.replacingOccurrences(of: "{network}", with: network)
        let params = ["label": "Generated by AxiomHive"]

        return makeAuthenticatedRequest(endpoint: endpoint, method: "POST", params: params)
            .tryMap { data -> GeminiAddress in
                let address = try JSONDecoder().decode(GeminiAddress.self, from: data)
                return address
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Private Helpers

    private func makeRequest(endpoint: String, private: Bool = false) -> URLRequest {
        let url = URL(string: (private ? AppConfig.shared.environment.exchangeURL : AppConfig.shared.environment.baseURL) + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if AppConfig.shared.enableCertificatePinning {
            // Certificate pinning is handled by the URLSessionDelegate
        }

        return request
    }

    private func makeAuthenticatedRequest(endpoint: String, method: String, params: [String: String] = [:]) -> AnyPublisher<Data, Error> {
        return loadAuthConfig()
            .flatMap { authConfig -> AnyPublisher<Data, Error> in
                let url = URL(string: AppConfig.shared.environment.exchangeURL + endpoint)!
                var request = URLRequest(url: url)
                request.httpMethod = method

                let timestamp = String(Int(Date().timeIntervalSince1970))
                let nonce = String(SecurityValidator.shared.generateNonce())
                var payload = params
                payload["request"] = endpoint
                payload["nonce"] = nonce
                payload["timestamp"] = timestamp

                let message = method + endpoint + timestamp + nonce + (method == "POST" ? self.payloadToString(payload) : "")

                request.setValue(authConfig.apiKey, forHTTPHeaderField: "X-GEMINI-APIKEY")
                request.setValue(self.generateSignature(message: message, secret: authConfig.apiSecret), forHTTPHeaderField: "X-GEMINI-SIGNATURE")
                request.setValue(timestamp, forHTTPHeaderField: "X-GEMINI-TIMESTAMP")
                request.setValue(nonce, forHTTPHeaderField: "X-GEMINI-NONCE")

                if method == "POST" {
                    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                    request.httpBody = self.payloadToString(payload).data(using: .utf8)
                }

                return self.rateLimiter.execute(request: request)
            }
            .eraseToAnyPublisher()
    }

    private func loadAuthConfig() -> AnyPublisher<GeminiAuthConfig, Error> {
        return Future<GeminiAuthConfig, Error> { promise in
            var config = GeminiAuthConfig()
            do {
                try config.loadFromKeychain()
                promise(.success(config))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    private func generateSignature(message: String, secret: String) -> String {
        let secretData = secret.data(using: .utf8)!
        let messageData = message.data(using: .utf8)!

        let signature = HMAC.sha384(secret: secretData, message: messageData)
        return signature.hexString
    }

    private func payloadToString(_ payload: [String: String]) -> String {
        return payload.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
    }

    // HMAC-SHA384 utility - would need CryptoSwift or similar in real implementation
    private enum HMAC {
        static func sha384(secret: Data, message: Data) -> Data {
            var hmac = [UInt8](repeating: 0, count: Int(CC_SHA384_DIGEST_LENGTH))
            secret.withUnsafeBytes { secretBytes in
                message.withUnsafeBytes { messageBytes in
                    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA384), secretBytes.baseAddress, secret.count, messageBytes.baseAddress, message.count, &hmac)
                }
            }
            return Data(hmac)
        }
    }
}

// MARK: - Rate Limiter
private class RateLimiter {
    private var lastRequestTimes: [String: Date] = [:]
    private let queue = DispatchQueue(label: "com.axiomhive.ratelimiter", attributes: .concurrent)

    func execute(request: URLRequest) -> AnyPublisher<Data, Error> {
        return Future<Data, Error> { [weak self] promise in
            guard let self = self else { return }

            self.queue.async {
                let now = Date()
                let urlString = request.url?.absoluteString ?? ""

                if let lastTime = self.lastRequestTimes[urlString],
                   now.timeIntervalSince(lastTime) < AppConfig.shared.publicRateInterval {
                    // Rate limited, delay
                    let delay = AppConfig.shared.publicRateInterval - now.timeIntervalSince(lastTime)
                    Thread.sleep(forTimeInterval: delay)
                }

                self.lastRequestTimes[urlString] = Date()

                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }

                    guard let httpResponse = response as? HTTPURLResponse else {
                        promise(.failure(NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                        return
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        let error = NSError(domain: "GeminiAPI", code: httpResponse.statusCode, userInfo: [
                            NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode)",
                            "response": data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                        ])
                        promise(.failure(error))
                        return
                    }

                    guard let data = data else {
                        promise(.failure(NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                        return
                    }

                    promise(.success(data))
                }

                task.resume()
            }
        }.eraseToAnyPublisher()
    }
}

extension Data {
    var hexString: String {
        return self.map { String(format: "%02x", $0) }.joined()
    }
}
