import Foundation

enum SharedStore {
    static var group: String { Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String ?? "" }
    static var directory: URL? {
        guard !group.isEmpty else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    }
    static var available: Bool { directory != nil }

    static func read<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let url = directory?.appendingPathComponent(name),
              let data = try? Data(contentsOf: url), data.count < 100_000 else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func write<T: Encodable>(_ item: T, to name: String) throws {
        guard let url = directory?.appendingPathComponent(name) else { throw PilotError.configuration }
        try JSONEncoder().encode(item).write(to: url, options: [.atomic, .completeFileProtection])
    }


    static func remove(_ name: String) throws {
        guard let url = directory?.appendingPathComponent(name) else { throw PilotError.configuration }
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    /// Removes ephemeral conversation data. Settings and credentials are deliberately retained.
    static func clearSession() {
        try? remove(SharedFile.control)
        try? remove(SharedFile.state)
        try? remove(SharedFile.stop)
    }

    static var settings: Settings { read(SharedFile.settings, as: Settings.self) ?? Settings() }
    static var control: Control { read(SharedFile.control, as: Control.self) ?? Control() }
    static var state: BroadcastState { read(SharedFile.state, as: BroadcastState.self) ?? BroadcastState() }
}
