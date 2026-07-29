import AppKit
import SwiftUI
import Testing
@testable import Caffeinum

/// Renders the menu panel offscreen so its layout can be inspected without
/// taking a screenshot. Set `CAFFEINUM_RENDER_DIR` to keep the PNGs somewhere
/// useful; otherwise they land in the temporary directory.
@Suite("Menu rendering", .serialized)
@MainActor
struct MenuRenderTests {

    private var outputDirectory: URL {
        if let path = ProcessInfo.processInfo.environment["CAFFEINUM_RENDER_DIR"] {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: NSTemporaryDirectory())
    }

    @Test("the collapsed panel renders")
    func collapsed() throws {
        try render(MenuContentView(coordinator: AppCoordinator.shared), named: "panel-collapsed")
    }

    @Test("the panel renders with the events list open")
    func expanded() throws {
        try render(MenuContentView(coordinator: AppCoordinator.shared, showingEvents: true),
                   named: "panel-expanded")
    }

    @Test("the panel renders during an active timed session")
    func awake() throws {
        let coordinator = AppCoordinator.shared
        coordinator.preferences.duration = .hour2
        coordinator.setAwake(true)
        defer {
            coordinator.setAwake(false)
            coordinator.preferences.duration = .indefinite
        }
        try render(MenuContentView(coordinator: coordinator), named: "panel-awake")
    }

    private func render(_ view: some View, named name: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        let image = try #require(renderer.nsImage, "ImageRenderer produced nothing")
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)

        let tiff = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: tiff))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let url = outputDirectory.appendingPathComponent("\(name).png")
        try png.write(to: url)
        print("rendered \(url.path) (\(Int(image.size.width))×\(Int(image.size.height)))")
    }
}
