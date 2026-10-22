#if DEBUG
import SwiftUI

struct DevelopmentSettingsView: View {
    let onRepositoryChange: () -> Void
    let onAuthFlagChange: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: DevelopmentSettingsViewModel
    @State private var showsRepositoryPicker = false
    @State private var showsMockSessionPicker = false

    init(onRepositoryChange: @escaping () -> Void, onAuthFlagChange: @escaping () -> Void = {}) {
        self.onRepositoryChange = onRepositoryChange
        self.onAuthFlagChange = onAuthFlagChange
        _viewModel = State(initialValue: DevelopmentSettingsViewModel(onAuthFlagChange: onAuthFlagChange))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.sections, id: \.id) { section in
                    Section(section.id.title) {
                        ForEach(section.rows, id: \.id) { row in
                            DevelopmentSettingRowView(
                                row: row,
                                onButton: { selectButton(row.id) },
                                onToggle: { setToggle(row.id, isOn: $0) }
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Development Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Repository", isPresented: $showsRepositoryPicker) {
                ForEach(RepositoryMode.allCases, id: \.self) { mode in
                    Button(mode.title) {
                        if viewModel.changeRepositoryMode(to: mode) {
                            onRepositoryChange()
                        }
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("변경하면 모든 탭을 새로 만들고 스터디 목록으로 돌아갑니다.")
            }
            .alert("Mock 로그인 테스트", isPresented: $showsMockSessionPicker) {
                ForEach(DevelopmentSettingsStore.MockSession.allCases, id: \.self) { session in
                    Button(session.title) {
                        if viewModel.selectMockSession(session) {
                            onRepositoryChange()
                        }
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("실제 로그인 없이 테스트 상태로 탭을 새로 만듭니다. 선택은 재실행 후에도 유지되며, 기능 플래그는 별도로 설정합니다.")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기", action: { dismiss() })
                }
            }
        }
        .tint(Color(uiColor: AppTheme.Palette.accent))
    }

    private func selectButton(_ id: DevelopmentSettingRow.ID) {
        switch id {
        case .repository:
            showsRepositoryPicker = true
        case .mockSession:
            showsMockSessionPicker = true
        case .resetFlags:
            viewModel.resetFlagsToDefaults()
        case .featureFlag:
            break
        }
    }

    private func setToggle(_ id: DevelopmentSettingRow.ID, isOn: Bool) {
        guard case .featureFlag(let flagID) = id else { return }
        viewModel.setFlag(id: flagID, isEnabled: isOn)
    }
}
#endif
