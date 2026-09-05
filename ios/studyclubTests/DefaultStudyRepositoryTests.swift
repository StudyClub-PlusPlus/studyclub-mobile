import XCTest
@testable import studyclub

final class DefaultStudyRepositoryTests: XCTestCase {
    func testRepositoryReturnsDomainModels() async throws {
        let client = MockStudyAPIClient(scenario: .content, delayNanoseconds: 0)
        let repository = Repository(client: client)

        let studies = try await repository.fetchStudies()

        XCTAssertEqual(studies.count, 4)
        XCTAssertEqual(studies.first?.id, "ios-architecture")
    }

    func testRepositoryPreservesEmptySuccess() async throws {
        let client = MockStudyAPIClient(scenario: .empty, delayNanoseconds: 0)
        let repository = Repository(client: client)

        let studies = try await repository.fetchStudies()
        XCTAssertEqual(studies, [])
    }

    func testRepositoryMapsTransportFailure() async {
        let client = FailingStudyAPIClient()
        let repository = Repository(client: client)

        do {
            _ = try await repository.fetchStudies()
            XCTFail("Expected an unavailable error")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .unavailable)
        }
    }

    func testRepositoryRejectsDuplicateStudyIdentifiers() async {
        let duplicate = StudyDTO(
            id: "duplicate",
            category: "iOS",
            title: "중복 스터디",
            summary: "중복 식별자 검증",
            currentMembers: 1,
            maximumMembers: 4,
            status: "recruiting",
            topics: nil
        )
        let repository = Repository(
            client: DuplicateStudyAPIClient(studies: [duplicate, duplicate])
        )

        do {
            _ = try await repository.fetchStudies()
            XCTFail("Expected an invalid data error")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .invalidData)
        }
    }

    func testRepositoryPreservesCancellation() async {
        let client = MockStudyAPIClient(scenario: .loading, delayNanoseconds: 0)
        let repository = Repository(client: client)
        let task = Task { try await repository.fetchStudies() }

        await Task.yield()
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            return
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }
}

private struct FailingStudyAPIClient: StudyAPIClient {
    struct TransportError: Error {}

    func fetchStudies() async throws -> [StudyDTO] {
        throw TransportError()
    }
}

private struct DuplicateStudyAPIClient: StudyAPIClient {
    let studies: [StudyDTO]

    func fetchStudies() async throws -> [StudyDTO] {
        studies
    }
}
