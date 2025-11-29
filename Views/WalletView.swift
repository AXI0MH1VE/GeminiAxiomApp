import SwiftUI

struct WalletView: View {
    @StateObject private var viewModel = WalletViewModel()

    var body: some View {
        NavigationView {
            List(viewModel.balances) { balance in
                HStack {
                    Text(CurrencyInfo.all[balance.currency]?.name ?? balance.currency)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(balance.amount)")
                        Text("Available: \(balance.available)")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Wallet")
            .onAppear {
                loadBalances()
            }
            .refreshable {
                loadBalances()
            }
        }
    }

    private func loadBalances() {
        // Implement balance loading
    }
}
