import Alamofire
import Foundation

enum StudyRouter: URLRequestConvertible, Sendable {
    case studies(baseURL: URL)
    case study(baseURL: URL, id: Study.ID)

    func asURLRequest() throws -> URLRequest {
        switch self {
        case let .studies(baseURL):
            let url = baseURL.appending(path: "studies")
            var request = URLRequest(url: url)
            request.method = .get
            request.headers = [.accept("application/json")]
            return request
        case let .study(baseURL, id):
            let url = baseURL.appending(path: "studies").appending(path: id)
            var request = URLRequest(url: url)
            request.method = .get
            request.headers = [.accept("application/json")]
            return request
        }
    }
}
