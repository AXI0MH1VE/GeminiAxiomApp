import SwiftUI

struct TradingView: View {
    @StateObject private var viewModel = TradingViewModel()
    @StateObject private var marketViewModel = MarketDataViewModel()
    @State private var isPlacingOrder = false
    @State private var orderPlaced = false
    @State private var orderError: String?

    init() {
        // Set up WebSocket for real-time market data
        _marketViewModel = StateObject(wrappedValue: MarketDataViewModel())
        let handler = MarketDataWebSocketHandler(viewModel: marketViewModel)
        WebSocketManager.shared.delegate = handler
        WebSocketManager.shared.connect()
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Market Overview
                    marketOverviewSection

                    // Order Form
                    orderFormSection

                    // Quick Trade Buttons
                    quickActionsSection
                }
                .padding()
                .background(Color.gray.opacity(0.05).edgesIgnoringSafeArea(.all))
            }
            .navigationTitle("Trading")
            .navigationBarItems(
                leading: NavigationLink(destination: OrderHistoryView()) {
                    Image(systemName: "clock.arrow.circlepath")
                },
                trailing: Button(action: { marketViewModel.selectedSymbol = (marketViewModel.selectedSymbol == "btcusd") ? "ethusd" : "btcusd" }) {
                    Image(systemName: "arrow.2.circlepath")
                }
            )
            .alert(item: orderErrorBinding) { error in
                Alert(
                    title: Text("Order Error"),
                    message: Text(error),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var marketOverviewSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Market Overview")
                .font(.title2)
                .fontWeight(.bold)

            if let ticker = marketViewModel.tickers[marketViewModel.selectedSymbol] {
                HStack(spacing: 20) {
                    MarketInfoCard(title: "Bid", value: ticker.bid, color: .blue)
                    MarketInfoCard(title: "Ask", value: ticker.ask, color: .green)
                    MarketInfoCard(title: "Spread", value: spreadValue(ticker), color: .orange)
                }

                HStack {
                    Text("24h Volume: \(ticker.volume["today"] ?? "0")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let lastTrade = marketViewModel.recentTrades.first {
                        Text("Last Trade: $\(Double(lastTrade.price) ?? 0, specifier: "%.2f")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 10)
            } else {
                HStack {
                    Spacer()
                    VStack {
                        ProgressView()
                        Text("Loading market data...")
                            .foregroundColor(.gray)
                            .padding(.top, 5)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }

    private var orderFormSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Place Order")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                Section(header: Text("Trading Pair")) {
                    Picker("Symbol", selection: $viewModel.symbol) {
                        Text("BTC/USD").tag("btcusd")
                        Text("ETH/USD").tag("ethusd")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Order Type")) {
                    Picker("Type", selection: $viewModel.orderType) {
                        ForEach(TradingViewModel.OrderType.allCases, id: \.self) { type in
                            Text(type.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Order Details")) {
                    HStack {
                        TextField("Amount", text: $viewModel.amount)
                            .keyboardType(.decimalPad)
                        Text(currentSymbolUnit)
                            .foregroundColor(.secondary)
                    }

                    if viewModel.orderType == .limit {
                        HStack {
                            TextField("Price", text: $viewModel.price)
                                .keyboardType(.decimalPad)
                            Text("USD")
                                .foregroundColor(.secondary)
                        }
                    } else if viewModel.orderType == .market {
                        // For market orders, show estimated price
                        if let ticker = marketViewModel.tickers[viewModel.symbol] {
                            let estimatedPrice = viewModel.side == .buy ? ticker.ask : ticker.bid
                            HStack {
                                Text("Estimated Price")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("$\(Double(estimatedPrice) ?? 0, specifier: "%.2f")")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                Section(header: Text("Order Side")) {
                    Picker("Side", selection: $viewModel.side) {
                        Text("Buy").tag(TradingViewModel.OrderSide.buy)
                        Text("Sell").tag(TradingViewModel.OrderSide.sell)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Order Summary")) {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text("$\(viewModel.total, specifier: "%.2f")")
                    }

                    HStack {
                        Text("Est. Fee (0.35%)")
                        Spacer()
                        Text("$\(viewModel.total * 0.0035, specifier: "%.2f")")
                            .foregroundColor(.red)
                    }

                    Divider()

                    HStack {
                        Text("Total")
                            .fontWeight(.bold)
                        Spacer()
                        Text("$\(viewModel.total * 1.0035, specifier: "%.2f")")
                            .fontWeight(.bold)
                            .foregroundColor(viewModel.side.color)
                    }
                }
            }

            Button(action: placeOrder) {
                if isPlacingOrder {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Place \(viewModel.side.rawValue.capitalized) Order")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.side.color.opacity(viewModel.amount.isEmpty ? 0.5 : 1.0))
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(viewModel.amount.isEmpty || isPlacingOrder)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Actions")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 10) {
                QuickActionButton(label: "Buy 0.01", symbol: "plus.circle.fill", color: .green, action: {
                    viewModel.symbol = marketViewModel.selectedSymbol
                    viewModel.side = .buy
                    viewModel.amount = "0.01"
                    if let ticker = marketViewModel.tickers[viewModel.symbol] {
                        viewModel.price = ticker.ask
                    }
                })

                QuickActionButton(label: "Sell 0.01", symbol: "minus.circle.fill", color: .red, action: {
                    viewModel.symbol = marketViewModel.selectedSymbol
                    viewModel.side = .sell
                    viewModel.amount = "0.01"
                    if let ticker = marketViewModel.tickers[viewModel.symbol] {
                        viewModel.price = ticker.bid
                    }
                })

                QuickActionButton(label: "Market Buy", symbol: "bolt.fill", color: .blue, action: {
                    viewModel.symbol = marketViewModel.selectedSymbol
                    viewModel.side = .buy
                    viewModel.orderType = .market
                })

                QuickActionButton(label: "At Best", symbol: "arrow.up.arrow.down", color: .orange, action: {
                    viewModel.symbol = marketViewModel.selectedSymbol
                    viewModel.orderType = .market
                    if let ticker = marketViewModel.tickers[viewModel.symbol] {
                        if viewModel.side == .buy {
                            viewModel.price = ticker.ask
                        } else {
                            viewModel.price = ticker.bid
                        }
                    }
                })
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }

    private func spreadValue(_ ticker: GeminiTicker) -> String {
        if let bid = Double(ticker.bid), let ask = Double(ticker.ask) {
            let spread = ask - bid
            return String(format: "%.2f", spread)
        }
        return "0.00"
    }

    private var currentSymbolUnit: String {
        switch viewModel.symbol {
        case "btcusd": return "BTC"
        case "ethusd": return "ETH"
        default: return "CRYPTO"
        }
    }

    private var orderErrorBinding: Binding<String?> {
        Binding(
            get: { self.orderError },
            set: { self.orderError = $0 }
        )
    }

    private func placeOrder() {
        guard !isPlacingOrder && !viewModel.amount.isEmpty else { return }

        isPlacingOrder = true
        orderError = nil

        // In a real implementation, this would connect to the trading API
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Simulate order placement
            let orderSymbol = "\(viewModel.side.rawValue.capitalized) \(viewModel.amount) \(currentSymbolUnit)"
            print("✅ Simulated order placed: \(orderSymbol)")
            orderPlaced = true
            isPlacingOrder = false

            // Audit the action
            AuditLogger.shared.log(action: "ORDER_PLACED", details: [
                "symbol": viewModel.symbol,
                "side": viewModel.side.rawValue,
                "amount": viewModel.amount,
                "price": viewModel.price,
                "type": viewModel.orderType.rawValue
            ])
        }
    }
}

struct MarketInfoCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value.isEmpty ? "—" : value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct QuickActionButton: View {
    let label: String
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.title2)
                Text(label)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(color)
            .cornerRadius(8)
        }
    }
}

struct OrderHistoryView: View {
    var body: some View {
        List(0..<5) { index in
            NavigationLink(destination: OrderDetailView(orderId: "ORDER_\(index)")) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("BTC/USD Limit Buy")
                            .font(.headline)
                        Text("Filled • 0.01 BTC @ $45,000")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("$450.00")
                            .font(.headline)
                        Text("2 hours ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Order History")
    }
}

struct OrderDetailView: View {
    let orderId: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Order #\(orderId)")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 10) {
                    OrderDetailRow(label: "Symbol", value: "BTC/USD")
                    OrderDetailRow(label: "Type", value: "Limit Buy")
                    OrderDetailRow(label: "Amount", value: "0.01 BTC")
                    OrderDetailRow(label: "Price", value: "$45,000.00")
                    OrderDetailRow(label: "Status", value: "Filled")
                    OrderDetailRow(label: "Date", value: "Nov 29, 2025 2:46 AM")
                }
            }
            .padding()
        }
        .navigationTitle("Order Details")
    }
}

struct OrderDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
