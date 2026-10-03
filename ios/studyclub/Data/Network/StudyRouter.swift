import Alamofire
import Foundation

enum StudyRouter: URLRequestConvertible {
    case studies(offset: Int, limit: Int)
    case study(id: Study.ID)

    private static let baseURL = URL(string: "https://api.studyclub-plusplus.com/api/")!

    private var method: HTTPMethod { .get }

    private var path: String {
        switch self {
        case .studies, .study: "studies"
        }
    }

    private var headers: HTTPHeaders { [.accept("application/json")] }

    func asURLRequest() throws -> URLRequest {
        var url = Self.baseURL.appending(path: path)
        if case let .study(id) = self {
            url = url.appending(path: id)
        }
        if case let .studies(offset, limit) = self {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "status", value: "RECRUITING"),
                URLQueryItem(name: "offset", value: String(offset)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
            url = components.url!
        }
        var request = URLRequest(url: url)
        request.method = method
        request.headers = headers
        return request
    }
}
