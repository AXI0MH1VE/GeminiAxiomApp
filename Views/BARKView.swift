import SwiftUI

struct BARKView: View {
    @StateObject private var viewModel = BARKViewModel()

    var body: some View {
        NavigationView {
            List(viewModel.directives) { directive in
                VStack(alignment: .leading) {
                    Text(directive.type)
                        .font(.headline)
                    Text(directive.operatorId)
                        .font(.caption)
                }
            }
            .navigationTitle("BARK Directives")
        }
    }
}
