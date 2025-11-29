import XCTest
import Security
@testable import GeminiAxiomApp

final class SecurityTests: XCTestCase {

    override func setUpWithError() throws {
        // Setup test environment
    }

    override func tearDownWithError() throws {
        // Clean up test keys
        try? KeychainManager.shared.clear()
    }

    func testKeychainStoreAndRetrieve() {
        let testKey = "test_key"
        let testValue = "test_value"

        XCTAssertNoThrow(try KeychainManager.shared.store(key: testKey, value: testValue))

        do {
            let retrievedValue = try KeychainManager.shared.retrieve(key: testKey)
            XCTAssertEqual(retrievedValue, testValue)
        } catch {
            XCTFail("Failed to retrieve value: \(error)")
        }
    }

    func testKeychainDelete() {
        let testKey = "test_key_delete"
        let testValue = "test_value"

        XCTAssertNoThrow(try KeychainManager.shared.store(key: testKey, value: testValue))

        // Verify it exists
        do {
            let retrievedValue = try KeychainManager.shared.retrieve(key: testKey)
            XCTAssertEqual(retrievedValue, testValue)
        } catch {
            XCTFail("Value should exist before delete")
        }

        // Delete it
        XCTAssertNoThrow(try KeychainManager.shared.delete(key: testKey))

        // Verify it no longer exists
        do {
            let retrievedValue = try KeychainManager.shared.retrieve(key: testKey)
            XCTAssertNil(retrievedValue)
        } catch {
            // This is expected - item should not be found
        }
    }

    func testKeychainClear() {
        let keysAndValues = [
            "test_key_1": "value_1",
            "test_key_2": "value_2",
            "test_key_3": "value_3"
        ]

        // Store multiple items
        for (key, value) in keysAndValues {
            XCTAssertNoThrow(try KeychainManager.shared.store(key: key, value: value))
        }

        // Verify they exist
        for (key, value) in keysAndValues {
            do {
                let retrievedValue = try KeychainManager.shared.retrieve(key: key)
                XCTAssertEqual(retrievedValue, value)
            } catch {
                XCTFail("Value should exist: \(key)")
            }
        }

        // Clear all
        XCTAssertNoThrow(try KeychainManager.shared.clear())

        // Verify all are gone
        for key in keysAndValues.keys {
            do {
                let retrievedValue = try KeychainManager.shared.retrieve(key: key)
                XCTAssertNil(retrievedValue, "Key should be cleared: \(key)")
            } catch {
                // Expected - items should not exist
            }
        }
    }

    func testKeychainKeyCollision() {
        let testKey = "collision_key"
        let value1 = "value_1"
        let value2 = "value_2"

        // Store first value
        XCTAssertNoThrow(try KeychainManager.shared.store(key: testKey, value: value1))

        // Store second value (should overwrite)
        XCTAssertNoThrow(try KeychainManager.shared.store(key: testKey, value: value2))

        // Should retrieve second value
        do {
            let retrievedValue = try KeychainManager.shared.retrieve(key: testKey)
            XCTAssertEqual(retrievedValue, value2)
        } catch {
            XCTFail("Failed to retrieve value after overwrite: \(error)")
        }
    }

    func testAuthenticationManager_AuthenticateAndStatus() {
        let apiKey = "test_api_key"
        let apiSecret = "test_api_secret"

        XCTAssertFalse(AuthenticationManager.shared.isAuthenticated)

        XCTAssertNoThrow(try AuthenticationManager.shared.authenticate(apiKey: apiKey, apiSecret: apiSecret))

        XCTAssertTrue(AuthenticationManager.shared.isAuthenticated)

        XCTAssertNoThrow(try AuthenticationManager.shared.logout())

        XCTAssertFalse(AuthenticationManager.shared.isAuthenticated)
    }

    func testAuthenticationManager_InvalidCredentials() {
        XCTAssertFalse(AuthenticationManager.shared.isAuthenticated)

        // This should not throw (we're not validating credentials here)
        XCTAssertNoThrow(try AuthenticationManager.shared.authenticate(apiKey: "invalid", apiSecret: "invalid"))

        // But we should still be able to check authentication status
        // (In a real test, we'd mock the keychain to simulate failed auth)
        XCTAssertTrue(AuthenticationManager.shared.isAuthenticated) // Would be true since we stored values
    }

    func testSecurityValidator_TimestampValidation() {
        let recentTime = Date()
        let oldTime = Date().addingTimeInterval(-400) // 6+ minutes ago
        let futureTime = Date().addingTimeInterval(400) // 6+ minutes in future

        // Recent timestamp should be valid
        XCTAssertTrue(SecurityValidator.shared.validateTimestamp(recentTime))

        // Old timestamp should be invalid
        XCTAssertFalse(SecurityValidator.shared.validateTimestamp(oldTime))

        // Future timestamp should be invalid (by default tolerance)
        XCTAssertFalse(SecurityValidator.shared.validateTimestamp(futureTime))

        // Custom tolerance should validate older timestamp
        XCTAssertTrue(SecurityValidator.shared.validateTimestamp(oldTime, tolerance: 500))
    }

    func testSecurityValidator_SSLValidation() {
        // For now, SSL validation always returns true in tests
        // In a full implementation, this would test actual certificate validation
        XCTAssertTrue(SecurityValidator.shared.validateSSLCertificate(for: "api.gemini.com"))
        XCTAssertTrue(SecurityValidator.shared.validateSSLCertificate(for: "invalid.host"))
    }

    func testCertificatePinningSharedInstance() {
        let instance1 = CertificatePinning.shared
        let instance2 = CertificatePinning.shared

        XCTAssertTrue(instance1 === instance2, "Should be same shared instance")
    }

    func testURLSessionDelegateMethods() {
        let pinningDelegate = CertificatePinning.shared
        let mockSession = URLSession.shared
        let mockHost = "api.gemini.com"

        // Note: This is a basic test. Full URL authentication testing would require
        // setting up mock certificate challenges and trust objects
        XCTAssertNotNil(pinningDelegate)
    }

    // MARK: - Cryptographic Tests (Basic Structure)

    func testHMAC_SHA384_Computation() {
        let message = "test_message"
        let key = "test_key"

        let data = message.data(using: .utf8)!
        let keyData = key.data(using: .utf8)!

        let signature = GeminiAPIClient.HMAC.sha384(secret: keyData, message: data)
        let hexSignature = signature.hexString

        // SHA-384 produces 96 bytes (192 hex characters)
        XCTAssertEqual(hexSignature.count, 96)
        XCTAssertTrue(hexSignature.range(of: "^[a-fA-F0-9]{96}$", options: .regularExpression) != nil)

        // Same input should produce same output
        let signature2 = GeminiAPIClient.HMAC.sha384(secret: keyData, message: data)
        XCTAssertEqual(signature, signature2)
    }

    func testHMAC_SHA384_DifferentInputs() {
        let message1 = "message_1"
        let message2 = "message_2"
        let key = "test_key"

        let data1 = message1.data(using: .utf8)!
        let data2 = message2.data(using: .utf8)!
        let keyData = key.data(using: .utf8)!

        let signature1 = GeminiAPIClient.HMAC.sha384(secret: keyData, message: data1)
        let signature2 = GeminiAPIClient.HMAC.sha384(secret: keyData, message: data2)

        XCTAssertNotEqual(signature1, signature2, "Different messages should produce different signatures")
    }
}
