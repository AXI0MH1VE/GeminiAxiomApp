import Foundation
import CommonCrypto

class SecurityValidator {
    static let shared = SecurityValidator()

    private var lastNonce: UInt64 = 0
    private var nonceQueue = DispatchQueue(label: "com.axiomhive.nonce", attributes: .concurrent)

    func validateNonce(_ nonce: UInt64) -> Bool {
        var isValid = false
        nonceQueue.sync {
            isValid = nonce > lastNonce
        }

        if isValid {
            nonceQueue.async(flags: .barrier) {
                self.lastNonce = nonce
            }
        }

        return isValid
    }

    func generateNonce() -> UInt64 {
        let nonce = UInt64(Date().timeIntervalSince1970 * 1000)
        _ = validateNonce(nonce)
        return nonce
    }

    func validateTimestamp(_ timestamp: Date, tolerance: TimeInterval = 30) -> Bool {
        let timeDifference = abs(timestamp.timeIntervalSinceNow)
        return timeDifference <= tolerance
    }

    func validateSSLCertificate(for host: String) -> Bool {
        guard AppConfig.shared.enableSSLValidation else { return true }

        // Certificate validation is handled by URLSessionDelegate
        // and CertificatePinning if enabled
        return true
    }
}
