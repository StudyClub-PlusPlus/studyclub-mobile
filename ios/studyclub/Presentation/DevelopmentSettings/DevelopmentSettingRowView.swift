#if DEBUG
import SwiftUI

struct DevelopmentSettingRowView: View {
    let row: DevelopmentSettingRow
    let onButton: () -> Void
    let onToggle: (Bool) -> Void

    var body: some View {
        switch row.kind {
        case .button(let value):
            Button(action: onButton) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title)
                        if let value {
                            Text(value).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 12)
                    if value != nil {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .foregroundStyle(.primary)
            .accessibilityLabel(row.title)
            .accessibilityValue(value ?? "")
            .accessibilityIdentifier(row.accessibilityIdentifier + ".row")
        case .toggle(let isOn):
            Toggle(isOn: Binding(get: { isOn }, set: onToggle)) {
                Text(row.title)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { onToggle(!isOn) }
            }
            .accessibilityLabel(row.title)
            .accessibilityIdentifier(row.accessibilityIdentifier)
        }
    }
}
#endif
