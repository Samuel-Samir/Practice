import UIKit

struct Article: Decodable {
    let id: String
    let title: String
    let imageURL: URL
}

protocol NewsFeedViewControllerDelegate: AnyObject {
    func newsFeed(_ viewController: NewsFeedViewController, didSelect article: Article)
}

// MARK: - Image cache

final class ImageCache {
    static let shared = ImageCache()
    private var images: [URL: UIImage] = [:]

    func image(for url: URL, completion: @escaping (UIImage?) -> Void) {
        if let cached = images[url] {
            completion(cached)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            self.images[url] = image
            completion(image)
        }.resume()
    }
}

// MARK: - Cell

final class ArticleCell: UITableViewCell {
    static let reuseID = "ArticleCell"
    let thumbnail = UIImageView()
    let titleLabel = UILabel()

    func configure(with article: Article) {
        titleLabel.text = article.title
        ImageCache.shared.image(for: article.imageURL) { image in
            self.thumbnail.image = image
        }
    }
}

// MARK: - Screen

final class NewsFeedViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var delegate: NewsFeedViewControllerDelegate?
    var onArticleRead: ((Article) -> Void)?

    private let tableView = UITableView()
    private var articles: [Article] = []
    private var page = 0
    private var isLoading = false
    private let pageSize = 20

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ArticleCell.self, forCellReuseIdentifier: ArticleCell.reuseID)
        view.addSubview(tableView)

        NotificationCenter.default.addObserver(forName: .userDidLogout, object: nil, queue: nil) { _ in
            self.articles.removeAll()
            self.tableView.reloadData()
        }
        onArticleRead = { article in
            self.markAsRead(article)
        }
        loadNextPage()
    }

    private func loadNextPage() {
        guard !isLoading else { return }
        let url = URL(string: "https://api.example.com/news?page=\(page)&size=\(pageSize)")!
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data else { return }
            let newArticles = (try? JSONDecoder().decode([Article].self, from: data)) ?? []
            self.articles += newArticles
            self.page += 1
            self.isLoading = false
            self.tableView.reloadData()
        }.resume()
    }

    private func markAsRead(_ article: Article) {
        UserDefaults.standard.set(true, forKey: "read_\(article.id)")
    }

    // MARK: UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        articles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ArticleCell.reuseID, for: indexPath) as! ArticleCell
        cell.configure(with: articles[indexPath.row])
        return cell
    }

    // MARK: UITableViewDelegate

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == articles.count {
            loadNextPage()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let article = articles[indexPath.row]
        onArticleRead?(article)
        delegate?.newsFeed(self, didSelect: article)
    }
}
