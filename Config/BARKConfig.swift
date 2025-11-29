import Foundation

struct BARKConfig {
    static let shared = BARKConfig()

    let operatorId = "axiomhive:operator:alexis_m_adams"
    let version = "1.0"
    let algorithm = "Ed25519"
    let hashAlgorithm = "SHA3-256"

    // Dimensions
    let dimensions = [
        "technical",
        "regulatory",
        "ontological",
        "epistemological",
        "economic"
    ]

    // Directives
    struct DirectiveConfig {
        let maxExpirationSeconds: TimeInterval = 3600
        let minNonceIncrement: UInt64 = 1
        let allowedDirectiveTypes = [
            "PROTOCOL_DEFINITION",
            "ENFORCEMENT_ORDER",
            "STATE_TRANSITION",
            "AUDIT_REQUEST"
        ]
    }

    // Audit
    struct AuditConfig {
        let logPath = "bark_audit_log.jsonl"
        let maxLogSize: Int = 10_000_000  // 10MB
        let enableRemoteSync = true
        let remoteAuditEndpoint = "https://audit.axiomhive.io"
    }
}
