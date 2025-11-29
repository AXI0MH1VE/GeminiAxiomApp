import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = GeminiAxiomViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MarketDataView(viewModel: viewModel.marketData)
                .tabItem {
                    Label("Markets", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(0)

            TradingView()
                .tabItem {
                    Label("Trade", systemImage: "arrow.triangle.swap")
                }
                .tag(1)

            WalletView()
                .tabItem {
                    Label("Wallet", systemImage: "wallet.pass")
                }
                .tag(2)

            BARKView()
                .tabItem {
                    Label("BARK", systemImage: "shield.lefthalf.filled")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .onAppear {
            setupWebSocket()
        }
        .alert(item: errorBinding) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func setupWebSocket() {
        let webSocketHandler = MarketDataWebSocketHandler(viewModel: viewModel.marketData)
        WebSocketManager.shared.delegate = webSocketHandler
        WebSocketManager.shared.connect()
    }

    private var errorBinding: Binding<AppError?> {
        Binding(
            get: { viewModel.errorMessage.map { AppError(message: $0) } },
            set: { if $0 == nil { viewModel.clearError() } }
        )
    }
}

struct AppError: Identifiable {
    let id = UUID()
    let message: String
}

struct MarketDataView: View {
    @ObservedObject var viewModel: MarketDataViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Symbol Selector
                Picker("Symbol", selection: $viewModel.selectedSymbol) {
                    ForEach(SymbolInfo.commonSymbols) { symbol in
                        Text(symbol.displayName).tag(symbol.symbol)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top)

                // Market Stats
                if let ticker = viewModel.tickers[viewModel.selectedSymbol] {
                    VStack(spacing: 15) {
                        Text("Market Overview")
                            .font(.title2)
                            .fontWeight(.bold)

                        HStack(spacing: 30) {
                            MarketStatView(label: "Bid", value: ticker.bid, color: .blue)
                            MarketStatView(label: "Ask", value: ticker.ask, color: .green)
                            MarketStatView(label: "Last", value: ticker.last, color: .primary)
                        }

                        // Price Change Indicator (would need historical data)
                        HStack {
                            Text("24h Volume: \(ticker.volume["today"] ?? "0")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                } else {
                    VStack {
                        ProgressView()
                        Text("Loading market data...")
                            .foregroundColor(.gray)
                            .padding(.top, 5)
                    }
                    .padding(.top, 50)
                }

                // Order Book Preview
                if let orderBook = viewModel.orderBooks[viewModel.selectedSymbol] {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Order Book")
                            .font(.title3)
                            .fontWeight(.semibold)

                        HStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("Bids (Buy)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(orderBook.bids.prefix(5), id: \.self) { bid in
                                    HStack {
                                        Text("\(Double(bid[0] as? String ?? "0") ?? 0, specifier: "%.4f")")
                                            .foregroundColor(.green)
                                        Spacer()
                                        Text("\(Double(bid[1] as? String ?? "0") ?? 0, specifier: "%.6f")")
                                    }
                                    .font(.system(size: 12, design: .monospaced))
                                }
                            }

                            VStack(alignment: .leading) {
                                Text("Asks (Sell)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(orderBook.asks.prefix(5), id: \.self) { ask in
                                    HStack {
                                        Text("\(Double(ask[0] as? String ?? "0") ?? 0, specifier: "%.4f")")
                                            .foregroundColor(.red)
                                        Spacer()
                                        Text("\(Double(ask[1] as? String ?? "0") ?? 0, specifier: "%.6f")")
                                    }
                                    .font(.system(size: 12, design: .monospaced))
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }

                // Recent Trades
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Trades")
                        .font(.title3)
                        .fontWeight(.semibold)

                    List(viewModel.recentTrades.prefix(15)) { trade in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("$\(Double(trade.price) ?? 0, specifier: "%.2f")")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("\(Date(timeIntervalSince1970: Double(trade.timestampms) / 1000).timeAgo())")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(trade.type.capitalized)
                                    .font(.caption)
                                    .foregroundColor(trade.type == "buy" ? .green : .red)
                                Text("\(Double(trade.amount) ?? 0, specifier: "%.6f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .listStyle(.plain)
                    .frame(height: 200)
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }
            .navigationTitle("Market Data")
            .navigationBarItems(trailing: Button(action: {
                // Refresh data
                NotificationCenter.default.post(name: NSNotification.Name("RefreshMarketData"), object: nil)
            }) {
                Image(systemName: "arrow.clockwise")
            })
        }
    }
}

struct MarketStatView: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value.isEmpty ? "—" : value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

extension Date {
    func timeAgo() -> String {
        let now = Date()
        let difference = now.timeIntervalSince(self)

        if difference < 60 {
            return "Just now"
        } else if difference < 3600 {
            return "\(Int(difference / 60))m ago"
        } else if difference < 86400 {
            return "\(Int(difference / 3600))h ago"
        } else {
            return "\(Int(difference / 86400))d ago"
        }
    }
}
