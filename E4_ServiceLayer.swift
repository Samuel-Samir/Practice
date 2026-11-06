import Foundation

// MARK: - Session

final class SessionManager {
    static let shared = SessionManager()

    private var accessToken: String?
    private var pendingRequests: [(String?) -> Void] = []
    private var isRefreshing = false
    private let queue = DispatchQueue(label: "session.queue")

    lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    var currentToken: String? {
        queue.sync { accessToken }
    }

    func withValidToken(_ completion: @escaping (String?) -> Void) {
        queue.async {
            if let token = self.accessToken {
                completion(token)
                return
            }
            self.pendingRequests.append(completion)
            if self.isRefreshing { return }
            self.isRefreshing = true
            self.refreshToken { token in
                self.queue.sync {
                    self.accessToken = token
                    self.isRefreshing = false
                    self.pendingRequests.forEach { $0(token) }
                    self.pendingRequests.removeAll()
                }
            }
        }
    }

    private func refreshToken(completion: @escaping (String?) -> Void) {
        let url = URL(string: "https://api.example.com/auth/refresh")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            let token = data.flatMap { String(data: $0, encoding: .utf8) }
            completion(token)
        }.resume()
    }

    func logout() {
        queue.sync {
            accessToken = nil
            DispatchQueue.main.sync {
                NotificationCenter.default.post(name: .userDidLogout, object: nil)
            }
        }
    }
}

// MARK: - Dashboard

final class DashboardLoader {
    private var results: [String: Data] = [:]
    private let resultsQueue = DispatchQueue(label: "dashboard.results", attributes: .concurrent)

    // Called from DashboardViewController.viewDidLoad (main thread).
    func loadDashboard(endpoints: [URL], completion: @escaping ([String: Data]) -> Void) {
        let group = DispatchGroup()
        for endpoint in endpoints {
            group.enter()
            SessionManager.shared.withValidToken { token in
                guard let token else { return }
                var request = URLRequest(url: endpoint)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                URLSession.shared.dataTask(with: request) { data, _, _ in
                    if let data {
                        self.results[endpoint.lastPathComponent] = data
                    }
                    group.leave()
                }.resume()
            }
        }
        group.wait()
        completion(results)
    }

    func cachedResult(for key: String) -> Data? {
        resultsQueue.sync { results[key] }
    }

    func store(_ data: Data, for key: String) {
        DispatchQueue.global().async(flags: .barrier) {
            self.results[key] = data
        }
    }

    // Called from the pull-to-refresh handler (main thread).
    func loadAllSequentially(_ urls: [URL]) -> [Data] {
        let semaphore = DispatchSemaphore(value: 0)
        var all: [Data] = []
        for url in urls {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data { all.append(data) }
                semaphore.signal()
            }.resume()
            semaphore.wait()
        }
        return all
    }
}
