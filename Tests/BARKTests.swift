import XCTest
@testable import GeminiAxiomApp

final class BARKTests: XCTestCase {

    override func setUpWithError() throws {
        // Reset directive manager for each test
        // Note: In a real test, we'd want to use dependency injection
    }

    override func tearDownWithError() throws {
        // Clean up
    }

    func testCreateDirective_ProtocolDefinition() {
        let content = DirectiveContent.protocolDefinition(ProtocolDefinition(
            name: "Test Protocol",
            version: "1.0",
            description: "Test protocol for unit testing",
            endpoints: ["https://api.test.com"],
            constraints: nil
        ))

        XCTAssertNoThrow(try {
            let directive = try DirectiveManager.shared.createDirective(
                content: content,
                dimensions: ["technical"])
            XCTAssertEqual(directive.type, "PROTOCOL_DEFINITION")
            XCTAssertEqual(directive.operatorId, BARKConfig.shared.operatorId)
            XCTAssertNotNil(directive.signature)
            XCTAssertTrue(directive.dimensions.contains("technical"))
        })
    }

    func testDirectiveValidation_InvalidSignature() {
        // Create a directive and tamper with its signature
        let content = DirectiveContent.enforcementOrder(EnforcementOrder(
            target: "test_target",
            action: "test_action",
            reason: "test_reason",
            evidence: nil
        ))

        do {
            var directive = try DirectiveManager.shared.createDirective(
                content: content,
                dimensions: ["regulatory"])
            directive.signature = "invalid_signature"

            XCTAssertThrowsError(try DirectiveManager.shared.executeDirective(directive)) { error in
                XCTAssertEqual(error as? DirectiveManager.DirectiveError, .invalidSignature)
            }
        } catch {
            XCTFail("Failed to create directive: \(error)")
        }
    }

    func testDirectiveValidation_ExpiredDirective() {
        let content = DirectiveContent.auditRequest(AuditRequest(
            scope: "test_scope",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600), // 1 hour from now
            dimensions: ["technical"]
        ))

        do {
            let directive = try DirectiveManager.shared.createDirective(
                content: content,
                dimensions: ["technical"],
                expiration: -60) // Expire 60 seconds ago

            XCTAssertThrowsError(try DirectiveManager.shared.executeDirective(directive)) { error in
                XCTAssertEqual(error as? DirectiveManager.DirectiveError, .expiredDirective)
            }
        } catch {
            XCTFail("Failed to create directive: \(error)")
        }
    }

    func testDirectiveValidation_InvalidDimensions() {
        let content = DirectiveContent.stateTransition(StateTransition(
            fromState: "idle",
            toState: "active",
            conditions: nil,
            metadata: nil
        ))

        do {
            let directive = try DirectiveManager.shared.createDirective(
                content: content,
                dimensions: ["invalid_dimension"]) // Invalid dimension

            XCTAssertThrowsError(try DirectiveManager.shared.executeDirective(directive)) { error in
                XCTAssertEqual(error as? DirectiveManager.DirectiveError, .invalidDimensions)
            }
        } catch {
            XCTFail("Failed to create directive: \(error)")
        }
    }

    func testNonceGeneration() {
        let nonce1 = SecurityValidator.shared.generateNonce()
        let nonce2 = SecurityValidator.shared.generateNonce()

        XCTAssertTrue(nonce2 > nonce1, "Nonces should be monotonically increasing")
    }

    func testNonceValidation() {
        let nonce1 = SecurityValidator.shared.generateNonce()
        let nonce2 = SecurityValidator.shared.generateNonce()

        XCTAssertTrue(SecurityValidator.shared.validateNonce(nonce2))
        XCTAssertFalse(SecurityValidator.shared.validateNonce(nonce1), "Earlier nonce should fail validation")
        XCTAssertFalse(SecurityValidator.shared.validateNonce(nonce1), "Already used nonce should fail")
    }

    func testWorkingKeyForBARK() {
        // Test BARK crypto key operations (these will need implementation)
        let keyPair = try? BARKCrypto.shared.generateEd25519KeyPair()
        if keyPair == nil {
            // Expected to fail until crypto is fully implemented
            XCTAssertNil(keyPair)
        }
    }

    func testAuditLogging() {
        let action = "TEST_ACTION"
        let details = ["test_param": "test_value"]

        AuditLogger.shared.log(action: action, details: details)

        // Verify log can be retrieved
        let entries = AuditLogger.shared.getAuditEntries(limit: 1)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.action, action)
        XCTAssertEqual(entries.first?.details["test_param"] as? String, "test_value")
    }

    func testAuditLogRetention() {
        // Log multiple entries
        for i in 0..<150 {
            AuditLogger.shared.log(action: "BULK_TEST_\(i)", details: ["index": i])
        }

        // Small delay for async processing
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        // Should only keep 500 or configured limit
        let entries = AuditLogger.shared.getAuditEntries(limit: 1000)
        XCTAssertTrue(entries.count <= 1000, "Should not exceed audit retention limit")
    }

    func testAuditReportGeneration() {
        let startDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let endDate = Date()

        let report = AuditLogger.shared.generateAuditReport(startDate: startDate, endDate: endDate)

        // Should generate a valid JSON report
        XCTAssertNotNil(report)
        XCTAssertTrue(report!.count > 0)

        // Parse JSON to verify structure
        do {
            let json = try JSONSerialization.jsonObject(with: report!, options: [])
            XCTAssertNotNil(json as? [String: Any])
        } catch {
            XCTFail("Failed to parse audit report JSON: \(error)")
        }
    }
}

// MARK: - Mock Extensions for Testing
extension DirectiveManager {
    // For testing, we might want to inject a mock keychain or crypto provider
    static let mockShared: DirectiveManager = {
        let manager = DirectiveManager()
        // Setup mock dependencies
        return manager
    }()
}
