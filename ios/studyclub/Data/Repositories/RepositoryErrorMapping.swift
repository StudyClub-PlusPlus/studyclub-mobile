import Alamofire
import Foundation

func mapRepositoryError(_ error: any Error) -> any Error {
    if error is CancellationError { return error }
    if let afError = error as? AFError, afError.isExplicitlyCancelledError {
        return CancellationError()
    }
    if let repositoryError = error as? RepositoryError { return repositoryError }
    return RepositoryError.unavailable
}
