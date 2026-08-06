import Alamofire
import Foundation

enum StudyRouter: URLRequestConvertible, Sendable {
    case studies(baseURL: URL)

    func asURLRequest() throws -> URLRequest {
        switch self {
        case let .studies(baseURL):
            let url = baseURL.appending(path: "studies")
            var request = URLRequest(url: url)
            request.method = .get
            request.headers = [.accept("application/json")]
            return request
        }
    }
}
