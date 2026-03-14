import SwiftUI

/// A single macro row: label + "current / target unit" + progress bar.
/// Used on the Dashboard and anywhere macro progress is displayed.
struct MacroProgressBar: View {
    let label: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color

    private var fraction: Double { min(current / max(target, 1), 1.0) }
    private var isOver: Bool { current > target }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(current)) / \(Int(target)) \(unit)")
                    .font(.subheadline.bold())
                    .foregroundStyle(isOver ? .orange : .primary)
            }
            ProgressView(value: fraction)
                .tint(isOver ? .orange : color)
        }
        .padding(.vertical, 2)
    }
}
