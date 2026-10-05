import Foundation

/// Maps the first three octets of a MAC address to a manufacturer.
///
/// The app bundle normally carries the full IEEE "oui.csv" registry, which the
/// build script downloads. A small built-in table covers common consumer
/// equipment when that file is missing, and a user may drop their own copy in
/// `~/Library/Application Support/Pejla/oui.csv`.
public final class OUIDatabase: @unchecked Sendable {
    private let table: [String: String]

    public static let builtIn = OUIDatabase(table: BuiltInOUI.table)

    public init(table: [String: String]) {
        self.table = table
    }

    public var count: Int { table.count }

    public func vendor(forMAC mac: String) -> String? {
        let prefix = MACAddress.oui(mac)
        guard prefix.count == 6 else { return nil }
        return table[prefix]
    }

    /// Parses the IEEE registry CSV: `Registry,Assignment,Organization Name,Organization Address`.
    public static func parseIEEECSV(_ text: String) -> [String: String] {
        var table: [String: String] = [:]
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let fields = CSV.parseLine(String(rawLine))
            guard fields.count >= 3, fields[0] == "MA-L" else { continue }
            let assignment = fields[1].trimmingCharacters(in: .whitespaces).uppercased()
            guard assignment.count == 6 else { continue }
            let organisation = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !organisation.isEmpty else { continue }
            table[assignment] = organisation
        }
        return table
    }

    public static func load(contentsOf url: URL) -> OUIDatabase? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let parsed = parseIEEECSV(text)
        guard !parsed.isEmpty else { return nil }
        return OUIDatabase(table: BuiltInOUI.table.merging(parsed) { _, fromFile in fromFile })
    }

    /// The user's own copy wins, then the copy in the app bundle, then the built-in table.
    public static func preferred() -> OUIDatabase {
        var candidates: [URL] = []
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            candidates.append(support.appendingPathComponent("Pejla/oui.csv"))
        }
        if let bundled = Bundle.main.url(forResource: "oui", withExtension: "csv") {
            candidates.append(bundled)
        }
        for url in candidates {
            if let database = load(contentsOf: url) {
                return database
            }
        }
        return builtIn
    }
}
