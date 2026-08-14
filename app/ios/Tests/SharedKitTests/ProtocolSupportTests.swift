import SharedKit
import XCTest

final class ProtocolSupportTests: XCTestCase {
    func testCompatibleProfileWithoutRealDeviceEvidenceIsExperimental() {
        let status = ProtocolSupportClassifier().classify(
            protocolKind: .vless,
            transport: .tcp,
            security: .reality,
            requiresUDP: true
        )
        XCTAssertEqual(status.level, .experimental)
        XCTAssertFalse(status.compatibleCores.isEmpty)
    }

    func testOnlyExactRealDeviceEvidencePromotesProfileToVerified() {
        let verified = ProtocolVerificationKey(
            protocolKind: .vless,
            transport: .tcp,
            security: .reality,
            requiresUDP: true
        )
        let classifier = ProtocolSupportClassifier(verifiedProfiles: [verified])

        XCTAssertEqual(
            classifier.classify(
                protocolKind: .vless,
                transport: .tcp,
                security: .reality,
                requiresUDP: true
            ).level,
            .verified
        )
        XCTAssertEqual(
            classifier.classify(
                protocolKind: .vless,
                transport: .webSocket,
                security: .reality,
                requiresUDP: true
            ).level,
            .experimental
        )
    }

    func testProfileWithoutCompatibleCoreIsUnsupportedWithStableReason() {
        let status = ProtocolSupportClassifier().classify(
            protocolKind: .hysteria2,
            transport: .splitHTTP,
            security: .tls,
            requiresUDP: true
        )
        XCTAssertEqual(status.level, .unsupported)
        XCTAssertTrue(status.compatibleCores.isEmpty)
        XCTAssertEqual(status.reasonCode, "unsupported.core-capability")
    }

    func testFirstBatchProtocolsUseExactTransportSecurityAndUDPConstraints() {
        let classifier = ProtocolSupportClassifier()
        XCTAssertEqual(
            classifier.classify(
                protocolKind: .anyTLS,
                transport: .tcp,
                security: .tls,
                requiresUDP: true
            ).level,
            .experimental
        )
        XCTAssertEqual(
            classifier.classify(
                protocolKind: .http,
                transport: .tcp,
                security: .tls,
                requiresUDP: true
            ).level,
            .unsupported
        )
        XCTAssertEqual(
            classifier.classify(
                protocolKind: .tuic,
                transport: .tcp,
                security: .tls,
                requiresUDP: true
            ).level,
            .unsupported
        )
        XCTAssertEqual(
            classifier.classify(
                protocolKind: .socks5,
                transport: .tcp,
                security: .none,
                requiresUDP: true
            ).level,
            .experimental
        )
    }
}
