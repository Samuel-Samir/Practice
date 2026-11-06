import SwiftUI

struct Position: Identifiable, Decodable {
    let id: String
    let symbol: String
    let quantity: Int
}

struct Price: Decodable {
    let symbol: String
    let value: Decimal
}

// MARK: - Auth

final class AuthTokenProvider: @unchecked Sendable {
    static let shared = AuthTokenProvider()
    private var token: String?
    private var expiry: Date = .distantPast

    func validToken() async throws -> String {
        if let token, expiry > Date() { return token }
        let (fresh, expiresIn) = try await refresh()
        token = fresh
        expiry = Date().addingTimeInterval(expiresIn)
        return fresh
    }

    private func refresh() async throws -> (String, TimeInterval) {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://api.example.com/token")!)
        let body = try JSONDecoder().decode([String: String].self, from: data)
        return (body["token"] ?? "", 3600)
    }
}

// MARK: - Prices

actor PriceCache {
    private var prices: [String: Decimal] = [:]

    func price(for symbol: String, api: PriceAPI) async throws -> Decimal {
        if let cached = prices[symbol] { return cached }
        let value = try await api.fetchPrice(symbol)
        prices[symbol] = value
        return value
    }
}

final class PriceAPI {
    func fetchPrice(_ symbol: String) async throws -> Decimal {
        let token = try await AuthTokenProvider.shared.validToken()
        var request = URLRequest(url: URL(string: "https://api.example.com/price/\(symbol)")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Price.self, from: data).value
    }

    // Used by an older widget extension that can't use async yet.
    func fetchPriceSync(_ symbol: String) -> Decimal {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Decimal = 0
        Task {
            result = (try? await fetchPrice(symbol)) ?? 0
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    func legacyPositions(completion: @escaping ([Position]?, Error?) -> Void) {
        // existing callback-based API, not shown
    }

    func positions() async throws -> [Position] {
        try await withCheckedThrowingContinuation { continuation in
            legacyPositions { positions, error in
                if let error {
                    continuation.resume(throwing: error)
                }
                if let positions {
                    continuation.resume(returning: positions)
                }
            }
        }
    }
}

// MARK: - ViewModel

final class PortfolioViewModel: ObservableObject {
    @Published var rows: [(Position, Decimal)] = []
    @Published var total: Decimal = 0
    @Published var errorMessage: String?

    private let api = PriceAPI()
    private let cache = PriceCache()
    private var refreshTask: Task<Void, Never>?

    func load() {
        Task.detached {
            do {
                let positions = try await self.api.positions()
                var rows: [(Position, Decimal)] = []
                for position in positions {
                    let price = try await self.cache.price(for: position.symbol, api: self.api)
                    rows.append((position, price))
                }
                self.rows = rows
                self.total = rows.reduce(0) { $0 + $1.1 * Decimal($1.0.quantity) }
            } catch {
                print(error)
            }
        }
    }

    func startLiveUpdates() {
        refreshTask = Task {
            while true {
                try? await Task.sleep(for: .seconds(2))
                load()
            }
        }
    }
}

// MARK: - View

struct PortfolioView: View {
    @StateObject private var viewModel = PortfolioViewModel()

    var body: some View {
        List(viewModel.rows, id: \.0.id) { row in
            HStack {
                Text(row.0.symbol)
                Spacer()
                Text("\(row.1)")
            }
        }
        .safeAreaInset(edge: .bottom) { Text("Total: \(viewModel.total)") }
        .onAppear { viewModel.startLiveUpdates() }
    }
}
