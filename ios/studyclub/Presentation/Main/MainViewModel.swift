import Combine
import Foundation

@MainActor
final class MainViewModel {
    enum LoadState: Equatable {
        case loading, content, empty, failure, unavailable
    }

    enum PageState: Equatable {
        case idle, loading, failure, stalled
    }

    private enum Request {
        case initial, more(Int), refresh

        var offset: Int {
            if case let .more(offset) = self { return offset }
            return 0
        }
    }

    private let stateSubject = CurrentValueSubject<LoadState, Never>(.loading)
    var statePublisher: AnyPublisher<LoadState, Never> { stateSubject.eraseToAnyPublisher() }
    var currentState: LoadState { stateSubject.value }

    private let repository: any RepositoryProtocol
    let isListAPIEnabled: Bool
    private var studiesByID: [Study.ID: Study] = [:]
    private var nextOffset: Int?
    private var requestTask: Task<Void, Never>?
    private(set) var items: [StudyCardCellViewModel] = []
    private(set) var pageState: PageState = .idle
    private(set) var isRefreshing = false
    private(set) var refreshError: String?

    convenience init() {
        self.init(
            repository: RepositoryFactory.makeListRepository(),
            isListAPIEnabled: DevelopmentSettingsStore().isEnabled(FeatureFlag.studyListAPI.definition)
        )
    }

    init(repository: any RepositoryProtocol, isListAPIEnabled: Bool = true) {
        self.repository = repository
        self.isListAPIEnabled = isListAPIEnabled
        fetch(.initial)
    }

    deinit { requestTask?.cancel() }

    func study(for id: Study.ID) -> Study? { studiesByID[id] }

    func loadMore() {
        guard isListAPIEnabled, requestTask == nil, pageState == .idle, let nextOffset else { return }
        fetch(.more(nextOffset))
    }

    func retryPage() {
        guard isListAPIEnabled, requestTask == nil, pageState == .failure, let nextOffset else { return }
        fetch(.more(nextOffset))
    }

    func refresh() {
        guard isListAPIEnabled, !isRefreshing else { return }
        requestTask?.cancel()
        fetch(.refresh)
    }

    private func fetch(_ request: Request) {
        let repository = repository
        if case .refresh = request {
            isRefreshing = true
            refreshError = nil
        } else if case .more = request {
            pageState = .loading
        }
        requestTask = Task { [weak self] in
            do {
                let page = try await repository.fetchStudies(offset: request.offset)
                guard !Task.isCancelled, let self else { return }
                self.apply(page, for: request)
            } catch let error as RepositoryError where error == .featureUnavailable {
                guard !Task.isCancelled, let self else { return }
                self.items = []
                self.studiesByID = [:]
                self.nextOffset = nil
                self.pageState = .idle
                self.isRefreshing = false
                self.refreshError = nil
                self.requestTask = nil
                self.stateSubject.send(.unavailable)
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.handleFailure(for: request)
            }
        }
        stateSubject.send(currentState)
    }

    private func apply(_ page: StudyPage, for request: Request) {
        // A zero-length page cannot move the cursor, even if total changed during the query.
        guard !page.studies.isEmpty || page.offset >= page.totalCount else {
            requestTask = nil
            isRefreshing = false
            if case .refresh = request {
                if pageState == .loading { pageState = .idle }
                refreshError = "목록이 변경됐어요. 다시 당겨서 새로고침해 주세요."
            } else {
                pageState = .stalled
            }
            stateSubject.send(items.isEmpty ? .failure : .content)
            return
        }

        let (offset, overflow) = page.offset.addingReportingOverflow(page.studies.count)
        guard !overflow else {
            handleFailure(for: request)
            return
        }
        switch request {
        case .initial, .refresh:
            studiesByID.removeAll()
            items.removeAll()
        case .more:
            break
        }
        for study in page.studies {
            let item = StudyCardCellViewModel(study: study)
            if let index = items.firstIndex(where: { $0.id == study.id }) {
                items[index] = item
            } else {
                items.append(item)
            }
            studiesByID[study.id] = study
        }
        nextOffset = isListAPIEnabled && offset < page.totalCount && !page.studies.isEmpty ? offset : nil
        pageState = .idle
        isRefreshing = false
        refreshError = nil
        requestTask = nil
        stateSubject.send(items.isEmpty ? .empty : .content)
    }

    private func handleFailure(for request: Request) {
        requestTask = nil
        isRefreshing = false
        switch request {
        case .initial:
            items = []
            studiesByID = [:]
            stateSubject.send(.failure)
        case .more:
            pageState = .failure
            stateSubject.send(.content)
        case .refresh:
            // Keep the previous cursor and pagination failure gate as well as the content.
            if pageState == .loading { pageState = .idle }
            refreshError = "새로고침하지 못했어요. 다시 당겨 주세요."
            stateSubject.send(items.isEmpty ? .failure : .content)
        }
    }
}
