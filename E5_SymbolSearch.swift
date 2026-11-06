import Combine
import UIKit

struct SearchResult: Decodable, Hashable {
    let symbol: String
    let name: String
}

// MARK: - ViewModel

final class SymbolSearchViewModel {
    @Published var query = ""
    @Published private(set) var results: [SearchResult] = []
    @Published private(set) var errorText: String?

    private var cancellables = Set<AnyCancellable>()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session

        $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .flatMap { query in
                self.search(query)
            }
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    self.errorText = error.localizedDescription
                }
            }, receiveValue: { results in
                self.results = results
            })
            .store(in: &cancellables)
    }

    private func search(_ query: String) -> AnyPublisher<[SearchResult], Error> {
        let url = URL(string: "https://api.example.com/search?q=\(query)")!
        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [SearchResult].self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}

// MARK: - Screen

final class SymbolSearchViewController: UIViewController, UISearchBarDelegate, UITableViewDataSource {
    private let viewModel = SymbolSearchViewModel()
    private let searchBar = UISearchBar()
    private let tableView = UITableView()
    private var cancellables = Set<AnyCancellable>()
    private var items: [SearchResult] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = searchBar
        tableView.frame = view.bounds
        view.addSubview(tableView)
        searchBar.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        viewModel.$results
            .sink { results in
                self.items = results
                self.tableView.reloadData()
            }
            .store(in: &cancellables)

        viewModel.$errorText
            .filter { $0 != nil }
            .assign(to: \.title, on: self)
            .store(in: &cancellables)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        viewModel.query = searchText
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row].symbol + " — " + items[indexPath.row].name
        return cell
    }
}
