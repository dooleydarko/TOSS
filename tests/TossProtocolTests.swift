import XCTest
@testable import TossSchema
@testable import TossProtocol

final class TossProtocolTests: XCTestCase {
    func testChecksumComputation() {
        let text = "Hello TOSS Protocol"
        let hex = TossSecurityUtils.sha256Hex(of: text)
        XCTAssertEqual(hex.count, 64)
        // Repeatable
        XCTAssertEqual(hex, TossSecurityUtils.sha256Hex(of: text))
    }

    func testFilenameSanitization() {
        let malicious1 = "../../../etc/passwd"
        let clean1 = TossSecurityUtils.sanitizeFilename(malicious1)
        XCTAssertFalse(clean1.contains(".."))
        XCTAssertFalse(clean1.contains("/"))

        let malicious2 = "my_handoff\0.json"
        let clean2 = TossSecurityUtils.sanitizeFilename(malicious2)
        XCTAssertFalse(clean2.contains("\0"))

        let titleWithSpaces = "Project TOSS — MVP 1.0"
        let cleanTitle = TossSecurityUtils.sanitizeFilename(titleWithSpaces)
        XCTAssertTrue(cleanTitle.contains("Project"))
        XCTAssertTrue(cleanTitle.contains("TOSS"))
    }
}
