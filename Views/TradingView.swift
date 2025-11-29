import SwiftUI

struct TradingView: View {
    @StateObject private var viewModel = TradingViewModel()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Trading Pair")) {
                    Picker("Symbol", selection: $viewModel.symbol) {
                        Text("BTC/USD").tag("btcusd")
                        Text("ETH/USD").tag("ethusd")
                    }
                }

                Section(header: Text("Order Type")) {
                    Picker("Type", selection: $viewModel.orderType) {
                        ForEach(TradingViewModel.OrderType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Order Details")) {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $viewModel.amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    if viewModel.orderType == .limit {
                        HStack {
                            Text("Price")
                            Spacer()
                            TextField("0.00", text: $viewModel.price)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
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

                Section(header: Text("Summary")) {
                    HStack {
                        Text("Total")
                        Spacer()
                        Text("$\(viewModel.total, specifier: "%.2f")")
                            .foregroundColor(.blue)
                    }
                }

                Button(action: placeOrder) {
                    Text("Place Order")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.side.color)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(viewModel.amount.isEmpty)
            }
            .navigationTitle("Trading")
        }
    }

    private func placeOrder() {
        // Implement order placement logic here
        print("Placing \(viewModel.side.rawValue) order for \(viewModel.amount) \(viewModel.symbol) at $\(viewModel.price)")
    }
}
