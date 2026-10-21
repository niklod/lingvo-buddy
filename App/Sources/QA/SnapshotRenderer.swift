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

    /// Writes one PNG per state and returns the written files.
    static func render(_ states: [SnapshotState], to directory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try states.map { state in
            let url = directory.appendingPathComponent(state.name).appendingPathExtension("png")
            try png(for: state).write(to: url, options: .atomic)
            return url
        }
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

    private static func png(for state: SnapshotState) throws -> Data {
        var image: CGImage?
        // Dynamic NSColors resolve against the current drawing appearance.
        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: state.view().background(Theme.Palette.desktop))
            renderer.scale = scale
            image = renderer.cgImage
        }
        guard let image else { throw RenderError.renderFailed(state.name) }
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw RenderError.encodeFailed(state.name)
        }
        return data
    }
}
