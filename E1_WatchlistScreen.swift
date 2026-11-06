import SwiftUI
import Combine

// MARK: - Model

struct Quote: Codable {
    let symbol: String
    let name: String
    let price: Double
    let change_percent: Double
    let updatedAt: Date
}

// MARK: - Service

final class QuoteService {
    static let shared = QuoteService()
    private let baseURL = "https://api.example.com/v1/quotes"

    func fetchQuotes(symbols: [String], completion: @escaping ([Quote]) -> Void) {
        let url = URL(string: baseURL + "?symbols=" + symbols.joined(separator: ","))!
        URLSession.shared.dataTask(with: url) { data, response, error in
            if error != nil {
                print("request failed")
                completion([])
                return
            }
            let quotes = try! JSONDecoder().decode([Quote].self, from: data!)
            completion(quotes)
        }.resume()
    }
}

// MARK: - ViewModel

final class WatchlistViewModel: ObservableObject {
    @Published var quotes: [Quote] = []
    @Published var isLoading = false
    @Published var lastError: String?

    var symbols: [String] = ["AAPL", "MSFT", "IBM", "TSLA"]
    private var timer: Timer?

    func load() {
        isLoading = true
        QuoteService.shared.fetchQuotes(symbols: symbols) { quotes in
            self.quotes = quotes
            self.isLoading = false
        }
    }

    func startAutoRefresh() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            self.load()
        }
    }

    func stopAutoRefresh() {
        timer = nil
    }

    func add(symbol: String) {
        symbols.append(symbol.uppercased())
        load()
    }

    func totalValue(holdings: [String: Int]) -> Double {
        var total = 0.0
        for quote in quotes {
            total += quote.price * Double(holdings[quote.symbol]!)
        }
        return total
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - Views

struct WatchlistView: View {
    @ObservedObject var viewModel = WatchlistViewModel()
    @State private var newSymbol = ""

    var body: some View {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency

        return NavigationStack {
            List {
                ForEach(viewModel.quotes.sorted { $0.change_percent > $1.change_percent }, id: \.name) { quote in
                    QuoteRow(quote: quote, formatter: formatter)
                }
            }
            .overlay { if viewModel.isLoading { ProgressView() } }
            .navigationTitle("Watchlist")
            .toolbar {
                TextField("Add symbol", text: $newSymbol)
                    .onSubmit { viewModel.add(symbol: newSymbol) }
            }
            .onAppear {
                viewModel.load()
                viewModel.startAutoRefresh()
            }
        }
    }
}

struct QuoteRow: View {
    let quote: Quote
    let formatter: NumberFormatter

    var body: some View {
        HStack {
            Text(quote.symbol).bold()
            Spacer()
            Text(formatter.string(from: NSNumber(value: quote.price))!)
            Text(String(format: "%.2f%%", quote.change_percent))
                .foregroundColor(quote.change_percent > 0 ? .green : .red)
        }
    }
}
