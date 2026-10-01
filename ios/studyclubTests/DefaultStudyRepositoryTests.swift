import XCTest
@testable import studyclub

final class DefaultStudyRepositoryTests: XCTestCase {
    private var study: StudyDTO {
        StudyDTO(id: "selected", category: "iOS", title: "스터디", summary: "요약",
                 currentMembers: 1, maximumMembers: 4, status: "recruiting", topics: nil)
    }

    func testDetailReturnsRequestedDomainModel() async throws {
        let repository = Repository(client: FixedStudyAPIInput(studies: [study]))
        let detail = try await repository.fetchStudy(id: "selected")
        XCTAssertEqual(detail.id, "selected")
        XCTAssertEqual(detail.title, "스터디")
    }

    func testDetailRejectsMismatchedIdentity() async {
        let dto = StudyDTO(id: "wrong", category: "iOS", title: "제목", summary: "요약",
                           currentMembers: 1, maximumMembers: 4, status: "recruiting", topics: nil)
        let repository = Repository(client: FixedStudyAPIInput(studies: [dto]))
        do {
            _ = try await repository.fetchStudy(id: "selected")
            XCTFail("Expected invalid data")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .invalidData)
        }
    }

    func testDetailPreservesCancellation() async {
        let repository = Repository(client: CancellableStudyAPIInput())
        let task = Task { try await repository.fetchStudy(id: "selected") }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("Expected cancellation")
        }
    }

    func testDetailMapsTransportFailure() async {
        let repository = Repository(client: FailingStudyAPIClient())
        do {
            _ = try await repository.fetchStudy(id: "selected")
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .unavailable)
        }
    }

    func testRepositoryReturnsDomainModels() async throws {
        let client = FixedStudyAPIInput(studies: [study])
        let repository = Repository(client: client)

        let studies = try await repository.fetchStudies()

        XCTAssertEqual(studies.count, 1)
        XCTAssertEqual(studies.first?.id, "selected")
    }

    func testRepositoryPreservesEmptySuccess() async throws {
        let client = FixedStudyAPIInput(studies: [])
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
            client: FixedStudyAPIInput(studies: [duplicate, duplicate])
        )

        do {
            _ = try await repository.fetchStudies()
            XCTFail("Expected an invalid data error")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .invalidData)
        }
    }

    func testRepositoryPreservesCancellation() async {
        let client = CancellableStudyAPIInput()
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
    func fetchStudy(id: Study.ID) async throws -> StudyDetailDTO {
        throw TransportError()
    }
    struct TransportError: Error {}

    func fetchStudies() async throws -> [StudyDTO] {
        throw TransportError()
    }
}

private struct FixedStudyAPIInput: StudyAPIClient {
    func fetchStudy(id: Study.ID) async throws -> StudyDTO {
        guard let study = studies.first else { throw RepositoryError.invalidData }
        return study
    }
    let studies: [StudyDTO]

    func fetchStudies() async throws -> [StudyDTO] {
        studies
    }
}

private struct CancellableStudyAPIInput: StudyAPIClient {
    func fetchStudy(id: Study.ID) async throws -> StudyDTO {
        try await Task.sleep(nanoseconds: 60_000_000_000)
        throw RepositoryError.unavailable
    }

    func fetchStudies() async throws -> [StudyDTO] {
        try await Task.sleep(nanoseconds: 60_000_000_000)
        return []
    }
}
