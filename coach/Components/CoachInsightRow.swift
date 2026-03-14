import SwiftUI

/// A single row displaying one CoachInsight: severity accent + icon + title + message.
struct CoachInsightRow: View {
    let insight: CoachInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(insight.severity.color)
                .frame(width: 3)
                .padding(.vertical, 2)

            Image(systemName: insight.icon)
                .foregroundStyle(insight.severity.color)
                .font(.subheadline)
                .frame(width: 22)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title).font(.subheadline.bold())
                Text(insight.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
