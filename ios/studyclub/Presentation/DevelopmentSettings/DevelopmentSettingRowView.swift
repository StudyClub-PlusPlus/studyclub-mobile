#if DEBUG
import SwiftUI

struct DevelopmentSettingRowView: View {
    let row: DevelopmentSettingRow
    let onButton: () -> Void
    let onToggle: (Bool) -> Void

    var body: some View {
        switch row.kind {
        case .button:
            Button(action: onButton) {
                HStack {
                    Text(row.title)
                    Spacer(minLength: 12)
                }
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .foregroundStyle(.primary)
        case .toggle(let isOn):
            Toggle(isOn: Binding(get: { isOn }, set: onToggle)) {
                Text(row.title)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { onToggle(!isOn) }
            }
        }
    }
}
#endif
