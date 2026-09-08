#if DEBUG
import SwiftUI

struct DevelopmentSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let onRepositoryChange: () -> Void
    @State private var viewModel: DevelopmentSettingsViewModel
    @State private var showsRepositoryPicker = false

    init(viewModel: DevelopmentSettingsViewModel, onRepositoryChange: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onRepositoryChange = onRepositoryChange
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
            .accessibilityIdentifier("development.list")
            .navigationTitle("Development Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기", action: { dismiss() })
                        .accessibilityIdentifier("development.close")
                }
            }
            .alert("Repository", isPresented: $showsRepositoryPicker) {
                ForEach(RepositoryMode.allCases, id: \.self) { mode in
                    Button(mode.title) { changeRepository(to: mode) }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("변경하면 모든 탭을 새로 만들고 스터디 목록으로 돌아갑니다.")
            }
        }
        .tint(Color(uiColor: AppTheme.Palette.accent))
    }

    private func selectButton(_ id: DevelopmentSettingRow.ID) {
        switch id {
        case .repository:
            showsRepositoryPicker = true
        case .resetFlags:
            viewModel.resetFlagsToDefaults()
            AccessibilityNotification.Announcement("Flag를 기본값으로 되돌렸습니다.").post()
        case .featureFlag:
            break
        }
    }

    private func setToggle(_ id: DevelopmentSettingRow.ID, isOn: Bool) {
        guard case .featureFlag(let flagID) = id else { return }
        viewModel.setFlag(id: flagID, isEnabled: isOn)
    }

    private func changeRepository(to mode: RepositoryMode) {
        guard viewModel.changeRepositoryMode(to: mode) else { return }
        onRepositoryChange()
    }
}
#endif
