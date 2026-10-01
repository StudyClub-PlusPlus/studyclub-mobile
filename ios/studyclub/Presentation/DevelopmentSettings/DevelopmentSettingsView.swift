#if DEBUG
import SwiftUI

struct DevelopmentSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: DevelopmentSettingsViewModel

    init(viewModel: DevelopmentSettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
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
