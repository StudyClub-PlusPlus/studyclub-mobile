import Alamofire
import Foundation

enum StudyRouter: URLRequestConvertible, Sendable {
    case studies
    case study(id: Study.ID)

    private var baseURL: URL {
        URL(string: "https://api.studyclub-plusplus.com/api/")!
    }

    private var method: HTTPMethod { .get }

    private var path: String {
        switch self {
        case .studies: "studies"
        case .study: "studies"
        }
    }

    private var headers: HTTPHeaders { [.accept("application/json")] }

    func asURLRequest() throws -> URLRequest {
        var url = baseURL.appending(path: path)
        if case let .study(id) = self {
            url = url.appending(path: id)
        }
        var request = URLRequest(url: url)
        request.method = method
        request.headers = headers
        return request
    }
}
