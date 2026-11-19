import Foundation

extension Notification.Name {
    public static let carAutoPadConnectedPhonesDidChange = Notification.Name("CarAutoPadConnectedPhonesDidChange")
}

public struct ConnectedPhoneRecord: Codable, Equatable, Identifiable {
    public let id: String
    public var deviceName: String
    public var hardwareModel: String
    public var ipAddress: String
    public var port: UInt16
    public var lastConnectedAt: Date

    public init(
        id: String,
        deviceName: String,
        hardwareModel: String,
        ipAddress: String,
        port: UInt16 = 5277,
        lastConnectedAt: Date = Date()
    ) {
        self.id = id
        self.deviceName = deviceName
        self.hardwareModel = hardwareModel
        self.ipAddress = ipAddress
        self.port = port
        self.lastConnectedAt = lastConnectedAt
    }

    public var displaySubtitle: String {
        let trimmedModel = hardwareModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedModel.isEmpty && trimmedModel.caseInsensitiveCompare(deviceName) != .orderedSame {
            return trimmedModel
        }
        return "\(ipAddress):\(port)"
    }
}

public final class ConnectedPhoneStore {
    public static let shared = ConnectedPhoneStore()

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let maxEntries: Int
    private let lock = NSLock()

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "carautopad-connected-phones-v1",
        maxEntries: Int = 20
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.maxEntries = max(1, maxEntries)
    }

    public func records() -> [ConnectedPhoneRecord] {
        lock.lock()
        defer { lock.unlock() }
        return loadLocked().sorted { $0.lastConnectedAt > $1.lastConnectedAt }
    }

    @discardableResult
    public func recordConnection(
        deviceName: String?,
        hardwareModel: String?,
        ipAddress: String,
        port: UInt16 = 5277,
        at date: Date = Date()
    ) -> ConnectedPhoneRecord {
        let cleanedIp = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedName = deviceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleanedModel = hardwareModel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let effectiveName: String
        if !cleanedName.isEmpty {
            effectiveName = cleanedName
        } else if !cleanedModel.isEmpty {
            effectiveName = cleanedModel
        } else if !cleanedIp.isEmpty {
            effectiveName = cleanedIp
        } else {
            effectiveName = "Android Phone"
        }

        let stableId: String
        if !cleanedName.isEmpty || !cleanedModel.isEmpty {
            stableId = "\(cleanedName.lowercased())|\(cleanedModel.lowercased())"
        } else {
            stableId = "ip|\(cleanedIp.lowercased())"
        }

        let record = ConnectedPhoneRecord(
            id: stableId,
            deviceName: effectiveName,
            hardwareModel: cleanedModel,
            ipAddress: cleanedIp,
            port: port,
            lastConnectedAt: date
        )

        lock.lock()
        var current = loadLocked()
        // If an IP-only placeholder exists for the same IP and we now have a real device name, replace it
        if !cleanedName.isEmpty || !cleanedModel.isEmpty {
            let ipPlaceholderId = "ip|\(cleanedIp.lowercased())"
            current.removeAll { $0.id == ipPlaceholderId }
        }
        if let idx = current.firstIndex(where: { $0.id == stableId }) {
            current[idx] = record
        } else {
            current.append(record)
        }
        current.sort { $0.lastConnectedAt > $1.lastConnectedAt }
        if current.count > maxEntries {
            current = Array(current.prefix(maxEntries))
        }
        saveLocked(current)
        lock.unlock()

        postChangedNotification()
        return record
    }

    public func remove(id: String) {
        lock.lock()
        var current = loadLocked()
        let before = current.count
        current.removeAll { $0.id == id }
        let changed = current.count != before
        if changed {
            saveLocked(current)
        }
        lock.unlock()

        if changed {
            postChangedNotification()
        }
    }

    public func clearAll() {
        lock.lock()
        userDefaults.removeObject(forKey: storageKey)
        lock.unlock()
        postChangedNotification()
    }

    private func loadLocked() -> [ConnectedPhoneRecord] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([ConnectedPhoneRecord].self, from: data)) ?? []
    }

    private func saveLocked(_ items: [ConnectedPhoneRecord]) {
        if let data = try? JSONEncoder().encode(items) {
            userDefaults.set(data, forKey: storageKey)
        }
    }

    private func postChangedNotification() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: .carAutoPadConnectedPhonesDidChange, object: self)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                NotificationCenter.default.post(name: .carAutoPadConnectedPhonesDidChange, object: self)
            }
        }
    }
}
