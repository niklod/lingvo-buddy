import SwiftUI

extension View {
    /// The design's dark inset text field (quick add, the tray's "Add word",
    /// Dictionary search). Font and text colour stay with the caller: they differ.
    func insetField(width: CGFloat? = nil, height: CGFloat, radius: CGFloat = Theme.Radius.button) -> some View {
        textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .frame(width: width, height: height)
            .background(Theme.Palette.inset, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.Palette.border, lineWidth: 1))
    }
}
