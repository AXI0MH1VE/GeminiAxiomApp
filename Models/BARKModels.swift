import Foundation

// MARK: - Directive Models

struct BARKDirective: Codable, Identifiable {
    let id: UUID
    let type: String
    let operatorId: String
    let timestamp: Date
    let nonce: UInt64
    var signature: String?
    let content: DirectiveContent
    let dimensions: [String]
    let expiration: Date?
    let metadata: [String: Any]?

    init(type: String, content: DirectiveContent, dimensions: [String] = [], expiration: TimeInterval = 3600) {
        self.id = UUID()
        self.type = type
        self.operatorId = BARKConfig.shared.operatorId
        self.timestamp = Date()
        self.nonce = SecurityValidator.shared.generateNonce()
        self.content = content
        self.dimensions = dimensions
        self.expiration = Date().addingTimeInterval(expiration)
        self.metadata = nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case operatorId = "operator"
        case timestamp
        case nonce
        case signature
        case content
        case dimensions
        case expiration
        case metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        operatorId = try container.decode(String.self, forKey: .operatorId)
        let timestampString = try container.decode(String.self, forKey: .timestamp)
        timestamp = ISO8601DateFormatter().date(from: timestampString) ?? Date()
        nonce = try container.decode(UInt64.self, forKey: .nonce)
        signature = try container.decodeIfPresent(String.self, forKey: .signature)
        content = try container.decode(DirectiveContent.self, forKey: .content)
        dimensions = try container.decode([String].self, forKey: .dimensions)
        if let expirationString = try container.decodeIfPresent(String.self, forKey: .expiration) {
            expiration = ISO8601DateFormatter().date(from: expirationString)
        } else {
            expiration = nil
        }
        metadata = try container.decodeIfPresent([String: Any].self, forKey: .metadata)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(operatorId, forKey: .operatorId)
        try container.encode(ISO8601DateFormatter().string(from: timestamp), forKey: .timestamp)
        try container.encode(nonce, forKey: .nonce)
        try container.encodeIfPresent(signature, forKey: .signature)
        try container.encode(content, forKey: .content)
        try container.encode(dimensions, forKey: .dimensions)
        if let expiration = expiration {
            try container.encode(ISO8601DateFormatter().string(from: expiration), forKey: .expiration)
        }
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}

enum DirectiveContent: Codable {
    case protocolDefinition(ProtocolDefinition)
    case enforcementOrder(EnforcementOrder)
    case stateTransition(StateTransition)
    case auditRequest(AuditRequest)
    case raw([String: Any])

    enum CodingKeys: String, CodingKey {
        case type
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "PROTOCOL_DEFINITION":
            let definition = try container.decode(ProtocolDefinition.self, forKey: .data)
            self = .protocolDefinition(definition)
        case "ENFORCEMENT_ORDER":
            let order = try container.decode(EnforcementOrder.self, forKey: .data)
            self = .enforcementOrder(order)
        case "STATE_TRANSITION":
            let transition = try container.decode(StateTransition.self, forKey: .data)
            self = .stateTransition(transition)
        case "AUDIT_REQUEST":
            let request = try container.decode(AuditRequest.self, forKey: .data)
            self = .auditRequest(request)
        default:
            let rawDict = try container.decode([String: Any].self, forKey: .data)
            self = .raw(rawDict)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .protocolDefinition(let definition):
            try container.encode("PROTOCOL_DEFINITION", forKey: .type)
            try container.encode(definition, forKey: .data)
        case .enforcementOrder(let order):
            try container.encode("ENFORCEMENT_ORDER", forKey: .type)
            try container.encode(order, forKey: .data)
        case .stateTransition(let transition):
            try container.encode("STATE_TRANSITION", forKey: .type)
            try container.encode(transition, forKey: .data)
        case .auditRequest(let request):
            try container.encode("AUDIT_REQUEST", forKey: .type)
            try container.encode(request, forKey: .data)
        case .raw(let dict):
            try container.encode("RAW", forKey: .type)
            try container.encode(dict, forKey: .data)
        }
    }
}

struct ProtocolDefinition: Codable {
    let name: String
    let version: String
    let description: String
    let endpoints: [String]
    let constraints: [String: Any]?
}

struct EnforcementOrder: Codable {
    let target: String
    let action: String
    let reason: String
    let evidence: [String]?
}

struct StateTransition: Codable {
    let fromState: String
    let toState: String
    let conditions: [String: Any]?
    let metadata: [String: Any]?
}

struct AuditRequest: Codable {
    let scope: String
    let startDate: Date
    let endDate: Date?
    let dimensions: [String]
}

// MARK: - Audit Models

struct BARKAuditEntry: Codable {
    let timestamp: Date
    let operatorId: String
    let action: String
    let directiveId: UUID?
    let details: [String: Any]
    let signature: String?

    var jsonRepresentation: String {
        let dict: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "operator": operatorId,
            "action": action,
            "directive_id": directiveId?.uuidString as Any,
            "details": details,
            "signature": signature as Any
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }
}
