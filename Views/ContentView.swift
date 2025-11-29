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
            VStack {
                Picker("Symbol", selection: $viewModel.selectedSymbol) {
                    ForEach(SymbolInfo.commonSymbols) { symbol in
                        Text(symbol.displayName).tag(symbol.symbol)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                if let ticker = viewModel.tickers[viewModel.selectedSymbol] {
                    VStack(spacing: 10) {
                        Text("Bid: \(ticker.bid)")
                        Text("Ask: \(ticker.ask)")
                        Text("Last: \(ticker.last)")
                    }
                    .font(.headline)
                } else {
                    Text("Loading market data...")
                        .foregroundColor(.gray)
                }

                List(viewModel.recentTrades.prefix(10)) { trade in
                    HStack {
                        Text(trade.price)
                        Spacer()
                        Text(trade.amount)
                        Spacer()
                        Text(trade.type).foregroundColor(trade.type == "buy" ? .green : .red)
                    }
                    .font(.subheadline)
                }
                .navigationTitle("Market Data")
            }
        }
    }
}
