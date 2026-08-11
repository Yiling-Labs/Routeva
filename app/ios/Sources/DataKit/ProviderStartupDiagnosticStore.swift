import Foundation
import SharedKit

public enum ProviderStartupStage: String, Codable, Sendable {
    case receivedRequest = "received_request"
    case loadingConfiguration = "loading_configuration"
    case validatingConfiguration = "validating_configuration"
    case applyingNetworkSettings = "applying_network_settings"
    case acquiringTunnelDescriptor = "acquiring_tunnel_descriptor"
    case startingPacketBridge = "starting_packet_bridge"
    case startingCore = "starting_core"
    case startingCommandServer = "starting_command_server"
    case startingCoreService = "starting_core_service"
    case running
    case stopping
}

public struct ProviderStartupDiagnosticSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let core: CoreIdentifier
    public let stage: ProviderStartupStage
    public let stableErrorCode: String?
    public let updatedAt: Date

    public init(
        schemaVersion: Int = ProviderStartupDiagnosticSnapshot.currentSchemaVersion,
        core: CoreIdentifier,
        stage: ProviderStartupStage,
        stableErrorCode: String? = nil,
        updatedAt: Date = .now
    ) {
        self.schemaVersion = schemaVersion
        self.core = core
        self.stage = stage
        self.stableErrorCode = stableErrorCode
        self.updatedAt = updatedAt
    }
}

/// A deliberately tiny, redacted handoff between the Packet Tunnel process
/// and the host App. It must never contain endpoints, credentials, manifests,
/// generated core configuration, or raw error descriptions.
public struct ProviderStartupDiagnosticStore: Sendable {
    public static let filename = "provider-startup-diagnostic.json"

    private let fileURL: URL?

    public init(fileManager: FileManager = .default) {
        fileURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: RoutevaDatabase.appGroupIdentifier
        )?.appendingPathComponent("Runtime", isDirectory: true)
            .appendingPathComponent(Self.filename, isDirectory: false)
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func clear(fileManager: FileManager = .default) {
        guard let fileURL, fileManager.fileExists(atPath: fileURL.path) else { return }
        try? fileManager.removeItem(at: fileURL)
    }

    public func record(
        core: CoreIdentifier,
        stage: ProviderStartupStage,
        stableErrorCode: String? = nil,
        now: Date = .now,
        fileManager: FileManager = .default
    ) {
        guard let fileURL else { return }
        let snapshot = ProviderStartupDiagnosticSnapshot(
            core: core,
            stage: stage,
            stableErrorCode: stableErrorCode,
            updatedAt: now
        )
        do {
            let directory = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            #if os(iOS)
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
            #endif
        } catch {
            // Diagnostics must never alter the VPN lifecycle.
        }
    }

    public func snapshot() -> ProviderStartupDiagnosticSnapshot? {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              data.count <= 2_048,
              let snapshot = try? JSONDecoder().decode(
                  ProviderStartupDiagnosticSnapshot.self,
                  from: data
              ),
              snapshot.schemaVersion == ProviderStartupDiagnosticSnapshot.currentSchemaVersion,
              snapshot.stableErrorCode?.count ?? 0 <= 96
        else { return nil }
        return snapshot
    }
}
