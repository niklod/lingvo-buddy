#if DEBUG
import AppKit
import SwiftUI

/// Renders registered view states offscreen to PNG files (`--snapshot`).
@MainActor
enum SnapshotRenderer {
    static let scale: CGFloat = 2

    enum RenderError: Error, LocalizedError {
        case renderFailed(String)
        case encodeFailed(String)

        var errorDescription: String? {
            switch self {
            case .renderFailed(let name): "Could not render snapshot \(name)."
            case .encodeFailed(let name): "Could not encode snapshot \(name) as PNG."
            }
        }
    }

    static func render(_ states: [SnapshotState], to directory: URL) async throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var urls: [URL] = []
        for state in states {
            let url = directory.appendingPathComponent(state.name).appendingPathExtension("png")
            try png(for: state, view: await state.view()).write(to: url, options: .atomic)
            urls.append(url)
        }
        return urls
    }

    /// The panel states whose content measures to an endless size, as "name: size".
    static func endlessPanels(_ states: [SnapshotState]) async -> [String] {
        var failures: [String] = []
        for state in states where state.isPanel {
            let size = FloatingPanel.fittingSize(of: NSHostingController(rootView: await state.view()))
            if !size.isFinite {
                failures.append("\(state.name): \(size)")
            }
        }
        return failures
    }

    /// A relative path lands in the app's temporary folder: the sandbox allows
    /// writes only inside the app container.
    static func directoryURL(_ path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(path, isDirectory: true)
    }

    private static func png(for state: SnapshotState, view: AnyView) throws -> Data {
        let bitmap = state.usesWindow ? windowBitmap(for: view) : rendererBitmap(for: view)
        guard let bitmap else { throw RenderError.renderFailed(state.name) }
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderError.encodeFailed(state.name)
        }
        return data
    }

    private static func rendererBitmap(for view: AnyView) -> NSBitmapImageRep? {
        var image: CGImage?
        // Dynamic NSColors resolve against the current drawing appearance.
        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: view.background(Theme.Palette.desktop))
            renderer.scale = scale
            image = renderer.cgImage
        }
        return image.map(NSBitmapImageRep.init(cgImage:))
    }

    /// `ImageRenderer` draws AppKit-backed controls (toggles, steppers, pickers,
    /// recorders) as placeholders, so those states go through a real, offscreen window.
    private static func windowBitmap(for view: AnyView) -> NSBitmapImageRep? {
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: .darkAqua)
        // Whole points: a fractional height leaves an unpainted pixel row at the top.
        let size = NSSize(width: host.fittingSize.width.rounded(.up), height: host.fittingSize.height.rounded(.up))
        guard size.width > 0, size.height > 0 else { return nil }
        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: -10_000, y: -10_000), size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        host.display()
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        bitmap.size = size
        host.cacheDisplay(in: host.bounds, to: bitmap)
        window.close()
        return bitmap
    }
}
#endif
