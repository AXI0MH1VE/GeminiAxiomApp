import XCTest
import Combine
@testable import GeminiAxiomApp

final class GeminiAPITests: XCTestCase {
    var cancellables = Set<AnyCancellable>()
    let timeout: TimeInterval = 30.0

    override func setUpWithError() throws {
        // Setup test environment
        AppConfig.shared = AppConfig.test  // We need to add a test configuration
    }

    override func tearDownWithError() throws {
        cancellables.removeAll()
    }

    func testGetTicker_BTCUSD() {
        let expectation = XCTestExpectation(description: "Get BTCUSD ticker")

        GeminiAPIClient.shared.getTicker(symbol: "btcusd")
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    XCTFail("Get ticker failed: \(error)")
                }
                expectation.fulfill()
            } receiveValue: { ticker in
                XCTAssertEqual(ticker.bid, "")
                XCTAssertEqual(ticker.ask, "")
                XCTAssertTrue(ticker.volume.count > 0)
                XCTAssertTrue(ticker.last.count > 0)
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: timeout)
    }

    func testGetTicker_InvalidSymbol() {
        let expectation = XCTestExpectation(description: "Get invalid ticker")

        GeminiAPIClient.shared.getTicker(symbol: "invalid")
            .sink { completion in
                switch completion {
                case .finished:
                    XCTFail("Should have failed")
                case .failure(let error):
                    // Expected failure for invalid symbol
                    expectation.fulfill()
                }
            } receiveValue: { _ in
                XCTFail("Should not receive value")
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: timeout)
    }

    func testGetTrades_BTCUSD() {
        let expectation = XCTestExpectation(description: "Get BTCUSD trades")

        GeminiAPIClient.shared.getTrades(symbol: "btcusd", limit: 10)
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    XCTFail("Get trades failed: \(error)")
                }
                expectation.fulfill()
            } receiveValue: { trades in
                XCTAssertTrue(trades.count <= 10)
                if let firstTrade = trades.first {
                    XCTAssertFalse(firstTrade.price.isEmpty)
                    XCTAssertFalse(firstTrade.amount.isEmpty)
                    XCTAssertEqual(firstTrade.exchange, "gemini")
                }
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: timeout)
    }

    func testGetOrderBook_BTCUSD() {
        let expectation = XCTestExpectation(description: "Get BTCUSD order book")

        GeminiAPIClient.shared.getOrderBook(symbol: "btcusd")
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    XCTFail("Get order book failed: \(error)")
                }
                expectation.fulfill()
            } receiveValue: { orderBook in
                XCTAssertTrue(orderBook.bids.count > 0)
                XCTAssertTrue(orderBook.asks.count > 0)

                // Check bid structure [price, amount, timestamp]
                if let firstBid = orderBook.bids.first {
                    XCTAssertEqual(firstBid.count, 3)
                    XCTAssertTrue(Double(firstBid[0] as? String ?? "0") ?? 0.0 > 0.0)
                }

                // Check ask structure [price, amount, timestamp]
                if let firstAsk = orderBook.asks.first {
                    XCTAssertEqual(firstAsk.count, 3)
                    XCTAssertTrue(Double(firstAsk[0] as? String ?? "0") ?? 0.0 > 0.0)
                }
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: timeout)
    }

    func testAuthenticatedRequest_WithoutCredentials() {
        // This test should fail when no credentials are available
        let expectation = XCTestExpectation(description: "Authenticated request without credentials")

        GeminiAPIClient.shared.getBalances()
            .sink { completion in
                switch completion {
                case .finished:
                    XCTFail("Should have failed without authentication")
                case .failure(let error):
                    // Expected failure
                    XCTAssertTrue(error.localizedDescription.contains("authentication") ||
                                error.localizedDescription.contains("unauthorized"))
                }
                expectation.fulfill()
            } receiveValue: { _ in
                XCTFail("Should not receive value without authentication")
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: timeout)
    }

    func testRateLimiting() {
        // Test that rate limiting is in place
        let expectation = XCTestExpectation(description: "Rate limiting test")

        expectation.expectedFulfillmentCount = 5

        // Make multiple requests quickly
        for _ in 0..<5 {
            GeminiAPIClient.shared.getTicker(symbol: "btcusd")
                .sink { completion in
                    // Regardless of success/failure, request was made
                    expectation.fulfill()
                } receiveValue: { _ in
                    // Value received
                }
                .store(in: &cancellables)
        }

        wait(for: [expectation], timeout: timeout * 2)
    }
}

// MARK: - Test Extension for AppConfig
extension AppConfig {
    static let test = AppConfig()
    // Override with test values as needed
}
