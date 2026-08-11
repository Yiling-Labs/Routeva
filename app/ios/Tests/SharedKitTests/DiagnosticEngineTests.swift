import SharedKit
import XCTest

final class DiagnosticEngineTests: XCTestCase {
    private let engine = DiagnosticEngine()

    func testProbeFailureAfterReadyTunnelIsClientFixableAndBounded() {
        let result = engine.evaluate([
            DiagnosticCheck(layer: .configuration, status: .passed),
            DiagnosticCheck(layer: .dns, status: .passed),
            DiagnosticCheck(layer: .tunnel, status: .passed),
            DiagnosticCheck(layer: .probe, status: .failed, errorCode: "probe.body_mismatch"),
        ])
        XCTAssertEqual(result.bucket, .clientFixable)
        XCTAssertEqual(result.stableErrorCode, "diagnostic.probe.failed")
        XCTAssertEqual(result.allowedActions, [.switchHealthyNode, .switchDNSPreset, .rebuildTunnel])
    }

    func testHandshakeFailureIsProviderSide() {
        let result = engine.evaluate([
            DiagnosticCheck(layer: .configuration, status: .passed),
            DiagnosticCheck(layer: .dns, status: .passed),
            DiagnosticCheck(layer: .tcpTLS, status: .passed),
            DiagnosticCheck(layer: .protocolHandshake, status: .failed, errorCode: "provider.rejected"),
        ])
        XCTAssertEqual(result.bucket, .providerSide)
        XCTAssertEqual(result.confidence, .high)
        XCTAssertEqual(result.allowedActions, [.switchHealthyNode, .refreshSubscription])
    }

    func testUnstableEvidenceTextIsDiscarded() {
        let result = engine.evaluate([
            DiagnosticCheck(
                layer: .configuration,
                status: .failed,
                errorCode: "token=https://secret.example/abc"
            ),
        ])
        XCTAssertNil(result.evidence.first?.errorCode)
    }

    func testNoFailureEvidenceReturnsUnknownWithoutActions() {
        let result = engine.evaluate([])
        XCTAssertEqual(result.bucket, .unknown)
        XCTAssertEqual(result.confidence, .low)
        XCTAssertTrue(result.allowedActions.isEmpty)
    }
}
