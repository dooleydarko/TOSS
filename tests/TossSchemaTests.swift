import XCTest
@testable import TossSchema

final class TossSchemaTests: XCTestCase {
    func testHandoffCreationAndValidation() throws {
        let handoff = TossHandoff(
            title: "Test Handoff",
            destination: .antigravity,
            objective: "Unit test objective",
            context: "Testing context",
            requirements: ["Req 1", "Req 2"],
            constraints: ["Constraint 1"],
            completed: ["Step 0"],
            nextActions: ["Step 1"],
            source: TossSource(type: .text, transcriptAvailable: false, rawInput: "Sample")
        )

        XCTAssertNoThrow(try handoff.validate())
        XCTAssertEqual(handoff.schemaVersion, "1.0.0")
        XCTAssertEqual(handoff.revision, 1)
    }

    func testInvalidHandoffFailsValidation() {
        let invalid = TossHandoff(
            title: "   ",
            destination: .antigravity,
            objective: "Obj",
            context: "Ctx",
            source: TossSource(type: .text)
        )
        XCTAssertThrowsError(try invalid.validate())
    }

    func testSerializationRoundTrip() throws {
        let original = TossHandoff(
            title: "Roundtrip Handoff",
            destination: .gpt,
            objective: "Ensure roundtrip fidelity",
            context: "JSON encode decode test",
            requirements: ["Requirement A"],
            constraints: ["Constraint B"],
            completed: [],
            nextActions: ["Verify"],
            source: TossSource(type: .voice, transcriptAvailable: true, rawInput: "Spoken note")
        )

        let data = try original.toJSONData()
        let decoded = try TossHandoff.fromJSONData(data)

        XCTAssertEqual(original.handoffId, decoded.handoffId)
        XCTAssertEqual(original.title, decoded.title)
        XCTAssertEqual(original.destination, decoded.destination)
        XCTAssertEqual(original.requirements, decoded.requirements)
    }

    func testMarkdownExport() {
        let handoff = TossHandoff(
            title: "Markdown Title",
            destination: .claude,
            objective: "Check markdown headers",
            context: "Markdown test",
            requirements: ["Alpha", "Beta"],
            nextActions: ["Action 1"],
            source: TossSource(type: .text)
        )

        let md = handoff.toMarkdown()
        XCTAssertTrue(md.contains("# Markdown Title"))
        XCTAssertTrue(md.contains("## Objective"))
        XCTAssertTrue(md.contains("- Alpha"))
        XCTAssertTrue(md.contains("- Beta"))
        XCTAssertTrue(md.contains("1. Action 1"))
    }

    func testRuleBasedFallbackProvider() async throws {
        let provider = RuleBasedFallbackProvider()
        let notes = """
        Feature X
        - must support offline export
        - require local pairing
        1. create swift test
        don't use third party clouds
        """

        let result = try await provider.structure(input: notes, context: "Test context")
        XCTAssertEqual(result.title, "Feature X")
        XCTAssertEqual(result.requirements.count, 2)
        XCTAssertEqual(result.nextActions.count, 1)
        XCTAssertEqual(result.constraints.count, 1)
    }
}
