import Combine
import Foundation

@MainActor
final class StudySearchViewModel {
    enum LoadState: Equatable { case idle, loading, content, empty, failure }
    enum PageState: Equatable { case idle, loading, failure, stalled }

    private let stateSubject = CurrentValueSubject<LoadState, Never>(.idle)
    var statePublisher: AnyPublisher<LoadState, Never> { stateSubject.eraseToAnyPublisher() }
    var currentState: LoadState { stateSubject.value }
    private let repository: any RepositoryProtocol
    let isSearchEnabled: Bool
    private var requestTask: Task<Void, Never>?
    private var isComposing = false
    private var nextOffset: Int?
    private(set) var query = StudySearchQuery(keyword: "")
    private(set) var items: [StudyCardCellViewModel] = []
    private(set) var pageState: PageState = .idle
    var canLoadMore: Bool { nextOffset != nil }

    convenience init() {
        self.init(repository: RepositoryFactory.makeStudyRepository(),
                  isSearchEnabled: DevelopmentSettingsStore().isEnabled(FeatureFlag.studySearch.definition))
    }

    init(repository: any RepositoryProtocol, isSearchEnabled: Bool = true) {
        self.repository = repository
        self.isSearchEnabled = isSearchEnabled
    }

    deinit { requestTask?.cancel() }

    func updateInput(_ text: String, isComposing: Bool) {
        let keyword = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard keyword != query.keyword || self.isComposing != isComposing else { return }
        self.isComposing = isComposing
        query = StudySearchQuery(keyword: keyword, phase: query.phase, category: query.category)
        replaceSearch()
    }

    func selectPhase(_ phase: StudyPhase?) {
        guard query.phase != phase else { return }
        query.phase = phase
        replaceSearch()
    }

    func selectCategory(_ category: StudyCategory?) {
        guard query.category != category else { return }
        query.category = category
        replaceSearch()
    }

    func endSearch() {
        requestTask?.cancel()
        requestTask = nil
        isComposing = false
        query = StudySearchQuery(keyword: "", phase: query.phase, category: query.category)
        clearResults()
        stateSubject.send(.idle)
    }

    func loadMore() {
        guard requestTask == nil, pageState == .idle, let nextOffset else { return }
        fetch(offset: nextOffset)
    }

    func retry() {
        guard requestTask == nil else { return }
        if pageState == .failure, let nextOffset {
            fetch(offset: nextOffset)
        } else {
            replaceSearch()
        }
    }

    private func replaceSearch() {
        requestTask?.cancel()
        requestTask = nil
        clearResults()
        guard isSearchEnabled, !query.keyword.isEmpty, !isComposing else {
            stateSubject.send(.idle)
            return
        }
        fetch(offset: 0)
    }

    private func clearResults() {
        items = []
        nextOffset = nil
        pageState = .idle
    }

    private func fetch(offset: Int) {
        let query = query
        let repository = repository
        if offset == 0 { stateSubject.send(.loading) } else { pageState = .loading }
        requestTask = Task { [weak self] in
            do {
                // This delay implements input debounce only; cancellation owns response ordering.
                if offset == 0 { try await Task.sleep(for: .milliseconds(300)) }
                try Task.checkCancellation()
                let page = try await repository.searchStudies(query: query, offset: offset)
                guard !Task.isCancelled, let self else { return }
                self.apply(page, expectedOffset: offset)
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.requestTask = nil
                if offset == 0 {
                    self.stateSubject.send(.failure)
                } else {
                    self.pageState = .failure
                    self.stateSubject.send(.content)
                }
            }
        }
        if offset != 0 { stateSubject.send(.content) }
    }

    private func apply(_ page: StudyPage, expectedOffset: Int) {
        requestTask = nil
        let (offset, overflow) = page.offset.addingReportingOverflow(page.studies.count)
        guard page.offset == expectedOffset, !overflow else {
            pageState = expectedOffset == 0 ? .idle : .failure
            stateSubject.send(items.isEmpty ? .failure : .content)
            return
        }
        guard !page.studies.isEmpty || page.offset >= page.totalCount else {
            pageState = .stalled
            stateSubject.send(items.isEmpty ? .failure : .content)
            return
        }
        for study in page.studies {
            let item = StudyCardCellViewModel(study: study)
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = item
            } else {
                items.append(item)
            }
        }
        nextOffset = !page.studies.isEmpty && offset < page.totalCount ? offset : nil
        pageState = .idle
        stateSubject.send(items.isEmpty ? .empty : .content)
    }
}
