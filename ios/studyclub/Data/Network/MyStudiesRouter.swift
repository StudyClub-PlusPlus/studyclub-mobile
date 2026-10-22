import Alamofire
import Foundation

enum MyStudiesRouter: URLRequestConvertible {
    case myStudies(accessToken: String)

    private static let baseURL = URL(string: "https://api.studyclub-plusplus.com/api/")!

    private var method: HTTPMethod { .get }

    private var path: String { "me/studies" }

    private var headers: HTTPHeaders { [.accept("application/json")] }

    func asURLRequest() throws -> URLRequest {
        switch self {
        case let .myStudies(accessToken):
            let trimmed = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw MyStudiesError.unauthorized
            }

            let url = Self.baseURL.appending(path: path)
            var request = URLRequest(url: url)
            request.method = method
            request.headers = headers
            request.headers.add(.authorization(bearerToken: trimmed))
            return request
        }
    }
}
