import SwiftUI

/// Design tokens only the quick-add panel uses.
enum QuickAddTheme {
    static let width: CGFloat = 520
    static let headerHeight: CGFloat = 56
    static let wordFontSize: CGFloat = 22
    static let pillHeight: CGFloat = 30
    static let fieldHeight: CGFloat = 34
    static let footerBackground = Theme.Palette.quickAddFooter
    static let selectedFill = Theme.Palette.accent.opacity(0.18)
}

extension ButtonStyle where Self == ThemeButtonStyle {
    /// The footer's smaller buttons, as tall as the pills.
    static func footer(_ kind: ThemeButtonStyle.Kind) -> ThemeButtonStyle {
        .theme(kind, height: QuickAddTheme.pillHeight, radius: Theme.Radius.smallButton)
    }
}

/// A translation choice: filled blue when chosen, dashed for "+ custom variant".
struct TranslationPill: View {
    let title: String
    let isSelected: Bool
    var isCustom = false
    /// A small note after the title ("machine translation") for a bubble that is not from a dictionary.
    var mark: String?
    /// The × of a bubble the learner typed; `nil` for bubbles they cannot remove.
    var remove: (() -> Void)?
    let action: () -> Void

    /// A tap gesture, not a Button: a Button would take keyboard focus away from
    /// the text fields, and Enter must always add the word.
    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: isSelected && !isCustom ? "\(title) ✓" : title)
                .font(.system(size: Theme.FontSize.body))
                .foregroundStyle(foreground)
            if let mark {
                Text(verbatim: mark)
                    .font(.system(size: Theme.FontSize.small))
                    .foregroundStyle(Theme.Palette.chipMineText)
            }
            if let remove {
                Image(systemName: "xmark")
                    .font(.system(size: Theme.FontSize.small, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: remove)
                    .accessibilityHidden(true)
            }
        }
            .padding(.horizontal, 12)
            .frame(height: QuickAddTheme.pillHeight)
            .background(Capsule().fill(isSelected ? QuickAddTheme.selectedFill : .clear))
            .overlay(border)
            .contentShape(Capsule())
            .fixedSize()
            .onTapGesture(perform: action)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityActions {
                if let remove { Button("Remove", action: remove) }
            }
    }

    private var foreground: Color {
        if isSelected { return Theme.Palette.textStrong }
        return isCustom ? Theme.Palette.textSecondary : Theme.Palette.textBody
    }

    private var borderColor: Color {
        isSelected ? Theme.Palette.accent : Theme.Palette.border
    }

    /// An empty dash array draws stray vertical lines on the capsule ends, so
    /// solid borders use the plain stroke.
    @ViewBuilder private var border: some View {
        if isCustom {
            Capsule().strokeBorder(borderColor, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        } else {
            Capsule().strokeBorder(borderColor, lineWidth: 1)
        }
    }
}

/// The dark inset text field of the design ("Where I saw it").
struct QuickAddField: View {
    let placeholder: String
    @Binding var text: String
    var italic = false

    var body: some View {
        TextField(text: $text, prompt: Text(verbatim: placeholder).foregroundStyle(Theme.Palette.textSecondary)) {
            Text(verbatim: placeholder)
        }
        .font(italic ? .system(size: Theme.FontSize.body).italic() : .system(size: Theme.FontSize.body))
        .foregroundStyle(Theme.Palette.textBody)
        .insetField(height: QuickAddTheme.fieldHeight)
    }
}

/// Lays children out in rows and wraps to the next row when one is full (the pills).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
