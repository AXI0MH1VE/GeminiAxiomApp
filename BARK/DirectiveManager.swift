import Foundation
import Combine

class DirectiveManager {
    static let shared = DirectiveManager()

    private var directives: [BARKDirective] = []
    private var cancellables = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "com.axiomhive.directives", attributes: .concurrent)

    private init() {
        loadPersistedDirectives()
    }

    func createDirective(content: DirectiveContent, dimensions: [String] = [], expiration: TimeInterval? = nil) throws -> BARKDirective {
        let directive = BARKDirective(
            type: content.directiveType,
            content: content,
            dimensions: dimensions,
            expiration: expiration != nil ? Date().addingTimeInterval(expiration!) : nil
        )

        // Sign the directive
        let signature = try signDirective(directive)
        var signedDirective = directive
        signedDirective.signature = signature.hexString

        // Validate before storing
        try validateDirective(signedDirective)

        // Store directive
        queue.async(flags: .barrier) {
            self.directives.append(signedDirective)
            self.persistDirective(signedDirective)
        }

        // Audit the creation
        AuditLogger.shared.log(action: "DIRECTIVE_CREATED", directiveId: signedDirective.id, details: ["type": signedDirective.type])

        return signedDirective
    }

    func executeDirective(_ directive: BARKDirective) throws {
        // Validate directive is still valid
        try validateDirectiveExecution(directive)

        // Execute based on content type
        switch directive.content {
        case .protocolDefinition:
            try executeProtocolDefinition(directive)
        case .enforcementOrder:
            try executeEnforcementOrder(directive)
        case .stateTransition:
            try executeStateTransition(directive)
        case .auditRequest:
            try executeAuditRequest(directive)
        case .raw:
            throw DirectiveError.unsupportedDirectiveType
        }

        // Audit execution
        AuditLogger.shared.log(action: "DIRECTIVE_EXECUTED", directiveId: directive.id, details: ["type": directive.type])
    }

    func getActiveDirectives() -> [BARKDirective] {
        return queue.sync {
            return directives.filter { directive in
                if let expiration = directive.expiration {
                    return expiration > Date()
                }
                return true
            }
        }
    }

    func revokeDirective(id: UUID) throws {
        queue.async(flags: .barrier) {
            if let index = self.directives.firstIndex(where: { $0.id == id }) {
                let directive = self.directives[index]
                self.directives[index].expiration = Date() // Mark as expired

                AuditLogger.shared.log(action: "DIRECTIVE_REVOKED", directiveId: id, details: ["original_type": directive.type])
            }
        }
    }

    private func signDirective(_ directive: BARKDirective) throws -> Data {
        let data = try JSONEncoder().encode(directive)
        let privateKeyData = try loadPrivateKey()
        return try BARKCrypto.shared.sign(data: data, with: privateKeyData)
    }

    private func validateDirective(_ directive: BARKDirective) throws {
        // Check signature
        guard let signatureString = directive.signature,
              let signature = signatureString.data(using: .hex) else {
            throw DirectiveError.invalidSignature
        }

        let data = try JSONEncoder().encode(directive)
        let publicKey = try loadPublicKey()
        let isValid = try BARKCrypto.shared.verify(signature: signature, for: data, with: publicKey)

        guard isValid else {
            throw DirectiveError.invalidSignature
        }

        // Check expiration
        if let expiration = directive.expiration, expiration <= Date() {
            throw DirectiveError.expiredDirective
        }

        // Check dimensions
        guard BARKConfig.shared.dimensions.contains(where: { directive.dimensions.contains($0) }) else {
            throw DirectiveError.invalidDimensions
        }
    }

    private func validateDirectiveExecution(_ directive: BARKDirective) throws {
        try validateDirective(directive)

        // Additional execution validation
        guard BARKConfig.shared.directive.allowedDirectiveTypes.contains(directive.type) else {
            throw DirectiveError.unsupportedDirectiveType
        }
    }

    private func executeProtocolDefinition(_ directive: BARKDirective) throws {
        // Implement protocol definition execution
        print("Executing protocol definition: \(directive)")
    }

    private func executeEnforcementOrder(_ directive: BARKDirective) throws {
        // Implement enforcement order execution
        print("Executing enforcement order: \(directive)")
    }

    private func executeStateTransition(_ directive: BARKDirective) throws {
        // Implement state transition execution
        print("Executing state transition: \(directive)")
    }

    private func executeAuditRequest(_ directive: BARKDirective) throws {
        // Implement audit request execution
        print("Executing audit request: \(directive)")
    }

    private func loadPrivateKey() throws -> Data {
        // Load from keychain or generate new
        let keychain = KeychainManager.shared
        if let privateKeyString = try keychain.retrieve(key: AppConfig.shared.keychain.barkPrivateKeyKey),
           let privateKey = privateKeyString.data(using: .hex) {
            return privateKey
        } else {
            // Generate new key pair
            let (privateKey, publicKey) = try BARKCrypto.shared.generateEd25519KeyPair()
            try keychain.store(key: AppConfig.shared.keychain.barkPrivateKeyKey, value: privateKey.hexString)
            try keychain.store(key: AppConfig.shared.keychain.barkPublicKeyKey, value: publicKey.hexString)
            return privateKey
        }
    }

    private func loadPublicKey() throws -> Data {
        let keychain = KeychainManager.shared
        guard let publicKeyString = try keychain.retrieve(key: AppConfig.shared.keychain.barkPublicKeyKey),
              let publicKey = publicKeyString.data(using: .hex) else {
            throw DirectiveError.keyNotFound
        }
        return publicKey
    }

    private func loadPersistedDirectives() {
        // Load directives from persistent storage
        // Implementation depends on storage mechanism (Core Data, UserDefaults, etc.)
    }

    private func persistDirective(_ directive: BARKDirective) {
        // Persist directive to storage
        // Implementation depends on storage mechanism
    }

    enum DirectiveError: Error {
        case invalidSignature
        case expiredDirective
        case invalidDimensions
        case unsupportedDirectiveType
        case keyNotFound
    }
}

extension Data {
    var hexString: String {
        return self.map { String(format: "%02x", $0) }.joined()
    }

    init?(hex: String) {
        let length = hex.count / 2
        var data = Data(capacity: length)
        for i in stride(from: 0, to: hex.count, by: 2) {
            let start = hex.index(hex.startIndex, offsetBy: i)
            let end = hex.index(start, offsetBy: 2)
            if let byte = UInt8(hex[start..<end], radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
        }
        self = data
    }

    init?(fromHex hex: String) {
        self.init(hex: hex)
    }
}

extension DirectiveContent {
    var directiveType: String {
        switch self {
        case .protocolDefinition: return "PROTOCOL_DEFINITION"
        case .enforcementOrder: return "ENFORCEMENT_ORDER"
        case .stateTransition: return "STATE_TRANSITION"
        case .auditRequest: return "AUDIT_REQUEST"
        case .raw: return "RAW"
        }
    }
}
