import SwiftUI

/// A two-column grid of toggleable chips.
struct SelectionGrid: View {
    let options: [String]
    @Binding var selected: Set<String>

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(options, id: \.self) { option in
                SelectionChip(
                    label: option.capitalized,
                    isSelected: selected.contains(option)
                )
                .onTapGesture {
                    if selected.contains(option) {
                        selected.remove(option)
                    } else {
                        selected.insert(option)
                    }
                }
            }
        }
    }
}

private struct SelectionChip: View {
    let label: String
    let isSelected: Bool

    var body: some View {
        Text(label)
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
