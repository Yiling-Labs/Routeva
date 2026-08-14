import CoreConfigKit
import DataKit
import Foundation
import SharedKit

struct CoreRuntimeConfiguration: Sendable {
    let manifest: RuntimeManifest
    let json: String
}

protocol RuntimeConfigurationLoading: Sendable {
    func load(manifestID: UUID?, for core: CoreIdentifier) async throws -> CoreRuntimeConfiguration
}

/// Loads only a manifest identifier from provider IPC. The complete core JSON
/// is reconstructed inside the Extension from SQLite metadata + Keychain and is
/// never written to the App Group.
struct KeychainRuntimeConfigurationLoader: RuntimeConfigurationLoading {
    private let repository: CoreConfigurationRepository?

    init() {
        if let database = try? RoutevaDatabase.openAppGroupDatabase() {
            repository = CoreConfigurationRepository(
                database: database,
                secrets: SharedKeychainStore()
            )
        } else {
            repository = nil
        }
    }

    func load(manifestID: UUID?, for core: CoreIdentifier) async throws -> CoreRuntimeConfiguration {
        guard let repository else { throw PacketTunnelRuntimeError.persistenceUnavailable }
        let compiled: CompiledCoreConfiguration
        if let manifestID {
            compiled = try await repository.load(manifestID: manifestID, for: core)
        } else {
            compiled = try await repository.loadCurrent(for: core)
        }
        return CoreRuntimeConfiguration(manifest: compiled.manifest, json: compiled.json)
    }
}

enum PacketTunnelRuntimeError: LocalizedError, Equatable {
    case missingManifestIdentifier
    case invalidManifestIdentifier
    case persistenceUnavailable
    case selectedCoreMismatch(expected: CoreIdentifier, actual: CoreIdentifier)
    case coreNotLinked(CoreIdentifier)
    case tunnelFileDescriptorUnavailable
    case packetBridgeFailure(String)
    case networkSettingsTimedOut
    case defaultInterfaceTimedOut
    case coreConfigurationValidationFailed
    case commandServerStartFailed
    case coreServiceRouteFailed
    case coreServicePluginFailed
    case coreServiceOutboundFailed
    case coreServiceDNSFailed
    case coreServiceTunnelFailed
    case coreServiceStartFailed
    case coreFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingManifestIdentifier:
            "The tunnel request did not contain a manifest identifier."
        case .invalidManifestIdentifier:
            "The tunnel request contained an invalid manifest identifier."
        case .persistenceUnavailable:
            "The shared runtime database is unavailable."
        case let .selectedCoreMismatch(expected, actual):
            "The manifest selected \(actual.rawValue), but this provider hosts \(expected.rawValue)."
        case let .coreNotLinked(core):
            "\(core.rawValue) is not linked in this build."
        case .tunnelFileDescriptorUnavailable:
            "The Packet Tunnel file descriptor is unavailable."
        case .packetBridgeFailure:
            "The public PacketFlow bridge failed."
        case .networkSettingsTimedOut:
            "Applying Packet Tunnel network settings timed out."
        case .defaultInterfaceTimedOut:
            "Waiting for the physical network interface timed out."
        case .coreConfigurationValidationFailed:
            "The core rejected the generated configuration."
        case .commandServerStartFailed:
            "The core command server could not start."
        case .coreServiceRouteFailed:
            "The core could not initialize routing."
        case .coreServicePluginFailed:
            "The core could not initialize the proxy plugin."
        case .coreServiceOutboundFailed:
            "The core could not initialize the proxy outbound."
        case .coreServiceDNSFailed:
            "The core could not initialize DNS."
        case .coreServiceTunnelFailed:
            "The core could not initialize the tunnel."
        case .coreServiceStartFailed:
            "The core service could not start."
        case let .coreFailure(message):
            message
        }
    }
}

extension PacketTunnelRuntimeError {
    var stableDiagnosticCode: String {
        switch self {
        case .missingManifestIdentifier:
            "provider.missing_manifest_id"
        case .invalidManifestIdentifier:
            "provider.invalid_manifest_id"
        case .persistenceUnavailable:
            "provider.shared_database_unavailable"
        case .selectedCoreMismatch:
            "provider.core_mismatch"
        case .coreNotLinked:
            "provider.core_not_linked"
        case .tunnelFileDescriptorUnavailable:
            "provider.tun_descriptor_unavailable"
        case let .packetBridgeFailure(stableCode):
            stableCode
        case .networkSettingsTimedOut:
            "provider.network_settings_timeout"
        case .defaultInterfaceTimedOut:
            "provider.default_interface_timeout"
        case .coreConfigurationValidationFailed:
            "provider.core_configuration_invalid"
        case .commandServerStartFailed:
            "provider.core_command_server_failed"
        case .coreServiceRouteFailed:
            "provider.core_service_route_failed"
        case .coreServicePluginFailed:
            "provider.core_service_plugin_failed"
        case .coreServiceOutboundFailed:
            "provider.core_service_outbound_failed"
        case .coreServiceDNSFailed:
            "provider.core_service_dns_failed"
        case .coreServiceTunnelFailed:
            "provider.core_service_tunnel_failed"
        case .coreServiceStartFailed:
            "provider.core_service_start_failed"
        case .coreFailure:
            "provider.core_failure"
        }
    }
}

func stableProviderStartupErrorCode(_ error: Error) -> String {
    if let runtimeError = error as? PacketTunnelRuntimeError {
        return runtimeError.stableDiagnosticCode
    }
    if let configurationError = error as? CoreConfigurationError {
        switch configurationError {
        case .manifestNotFound:
            return "provider.configuration_manifest_missing"
        case .manifestIdentifierMismatch, .profileNodeMismatch,
             .duplicateProfileIdentifier, .selectedProfileMissing:
            return "provider.configuration_mismatch"
        case .unsupportedManifestSchema:
            return "provider.configuration_schema_unsupported"
        case .nodeNotFound:
            return "provider.configuration_node_missing"
        case .credentialInvalid, .missingCredentialField:
            return "provider.configuration_credential_invalid"
        case .coreUnsupported:
            return "provider.configuration_core_unsupported"
        case .unsupportedProxyPlugin:
            return "provider.configuration_plugin_unsupported"
        case .unsupportedProxyOption:
            return "provider.configuration_proxy_option_unsupported"
        case .unsupportedRouteRule:
            return "provider.configuration_route_rule_unsupported"
        case .invalidJSON:
            return "provider.configuration_json_invalid"
        }
    }
    return "provider.unknown_failure"
}

enum ProviderStartOption {
    static let manifestID = "routeva.manifest-id"

    static func decodeManifestID(from options: [String: NSObject]?) throws -> UUID? {
        guard let value = options?[manifestID] as? NSString else { return nil }
        guard let identifier = UUID(uuidString: value as String) else {
            throw PacketTunnelRuntimeError.invalidManifestIdentifier
        }
        return identifier
    }
}
