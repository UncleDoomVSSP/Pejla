import SwiftUI
import PejlaCore

@main
struct PejlaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    init() {
        FileDescriptorLimit.raise()
    }

    var body: some Scene {
        Window("Pejla", id: "main") {
            ContentView(model: model, scanner: model.scanner)
                .frame(minWidth: 880, minHeight: 480)
        }
        .defaultSize(width: 1080, height: 660)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Pejla") { AboutPanel.show() }
            }
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Scan") {
                Button("Start Scan") { model.startScan() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(model.scanner.isScanning || !model.canScan)
                Button("Stop Scan") { model.scanner.stop() }
                    .keyboardShortcut(".", modifiers: .command)
                    .disabled(!model.scanner.isScanning)
                Divider()
                Button("Refresh Interfaces") { model.refreshInterfaces() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            CommandGroup(after: .saveItem) {
                Button("Export as CSV...") { Exporter.exportCSV(model.scanner.aliveHosts) }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(model.scanner.aliveHosts.isEmpty)
            }
        }
        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

/// The standard About panel with a credits block above the copyright line.
@MainActor
enum AboutPanel {
    static let author = "UncleDoomVSSP"
    static let repository = URL(string: "https://github.com/UncleDoomVSSP/Pejla")!

    static func show() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .paragraphStyle: paragraph,
        ]
        let credits = NSMutableAttributedString(string: "Made by \(author)\n", attributes: base)
        var link = base
        link[.link] = repository
        credits.append(NSAttributedString(string: repository.absoluteString + "\n", attributes: link))
        credits.append(NSAttributedString(string: "Released under the MIT License", attributes: base))

        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}
