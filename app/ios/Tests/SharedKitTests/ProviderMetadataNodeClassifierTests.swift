import SharedKit
import XCTest

final class ProviderMetadataNodeClassifierTests: XCTestCase {
    func testClassifiesDummyHosts() {
        XCTAssertTrue(ProviderMetadataNodeClassifier.isMetadata(displayName: "INFO", host: "www.g00gle.com"))
        XCTAssertTrue(ProviderMetadataNodeClassifier.isMetadata(displayName: "INFO", host: "127.0.0.1"))
        XCTAssertTrue(ProviderMetadataNodeClassifier.isMetadata(displayName: "INFO", host: "0.0.0.0"))
        XCTAssertTrue(ProviderMetadataNodeClassifier.isMetadata(displayName: "INFO", host: "localhost"))
        XCTAssertFalse(ProviderMetadataNodeClassifier.isMetadata(displayName: "HK-01", host: "hk.example.invalid"))
    }

    func testClassifiesLabeledQuotaAndExpiryWithoutWordList() {
        XCTAssertTrue(isMetadata("剩余流量：19.06% 57.71GB"))
        XCTAssertTrue(isMetadata("过期时间：2026-09-17 10:01:32"))
        XCTAssertTrue(isMetadata("套餐到期：2026-09-14"))
        XCTAssertTrue(isMetadata("距离下次重置剩余：29 天"))
        XCTAssertTrue(isMetadata("Expire: 2026-09-14"))
        XCTAssertTrue(isMetadata("Remaining: 12.5 GB"))
        XCTAssertFalse(isMetadata("US: Los Angeles 01"))
        XCTAssertFalse(isMetadata("香港[1.5x]-优化1"))
    }

    func testClassifiesEmbeddedURLOrFQDN() {
        XCTAssertTrue(isMetadata("域名: lgga.cb2077.com（墙内访问）"))
        XCTAssertTrue(isMetadata("Visit https://panel.example.com"))
        XCTAssertFalse(isMetadata("香港-域名优化1"))
        XCTAssertFalse(isMetadata("日本A05 | 下载专用"))
    }

    func testClassifiesInstructionSentencesButKeepsLongRealNodeNames() {
        XCTAssertTrue(isMetadata("若节点故障先更新订阅并设置订阅自动更新"))
        XCTAssertFalse(isMetadata("台湾原生住宅"))
        XCTAssertFalse(isMetadata("香港移动"))
        XCTAssertFalse(isMetadata("IEPL专线优化加速香港入口备用节点"))
        XCTAssertFalse(isMetadata("请更新订阅"))
    }

    func testBareMetricWithoutNodeIdentity() {
        XCTAssertTrue(isMetadata("19.06% 57.71GB"))
        XCTAssertFalse(isMetadata("香港1天试用"))
    }

    private func isMetadata(_ name: String, host: String = "node.example.invalid") -> Bool {
        ProviderMetadataNodeClassifier.isMetadata(displayName: name, host: host)
    }
}
