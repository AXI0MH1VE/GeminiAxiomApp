# GeminiAxiom App

**Production-Ready iOS Cryptocurrency Exchange Client with BARK Protocol Integration**

## Overview

GeminiAxiom App is a sophisticated iOS application that provides a secure, regulated cryptocurrency trading interface integrated with Gemini exchange APIs. The app implements advanced governance through the BARK (Blockchain Automated Regulatory & Knowledge) protocol, ensuring compliance and auditability across all trading operations.

## Features

### 💰 Cryptocurrency Trading
- Real-time market data (tickers, order books, trade feeds)
- Advanced order types (market, limit, stop-loss orders)
- Portfolio management and balance tracking
- Order history and status monitoring

### 🛡️ BARK Protocol Governance
- Multi-dimensional protocol enforcement (technical, regulatory, ontological, epistemological, economic)
- Cryptographic directive management with Ed25519 signatures
- Comprehensive audit logging with remote synchronization
- Automated compliance monitoring

### 🔐 Enterprise-Grade Security
- Keychain-based credential storage
- Certificate pinning for API endpoints
- HMAC-SHA384 request authentication
- Nonce-based replay attack prevention
- Rate limiting and DDoS protection

### 📱 Modern iOS Architecture
- SwiftUI native interface
- WebSocket real-time data streams
- Combine framework for reactive programming
- Complete Swift 5.5+ compatibility

## Project Structure

```
GeminiAxiomApp/
├── Config/                 # Application configuration
│   ├── AppConfig.swift     # Main app settings and environment
│   ├── GeminiConfig.swift  # Gemini API configuration
│   └── BARKConfig.swift    # BARK protocol settings
├── Security/               # Security and cryptography
│   ├── KeychainManager.swift
│   ├── CertificatePinning.swift
│   └── SecurityValidator.swift
├── Networking/             # API and WebSocket clients
│   ├── GeminiAPIClient.swift
│   ├── WebSocketManager.swift
│   └── AuthenticationManager.swift
├── BARK/                   # BARK protocol implementation
│   ├── BARKCrypto.swift    # Cryptographic operations
│   ├── DirectiveManager.swift # Directive lifecycle
│   └── AuditLogger.swift   # Audit logging system
├── Models/                 # Data models and view models
│   ├── GeminiModels.swift  # Gemini API data structures
│   ├── BARKModels.swift    # BARK protocol models
│   └── UIModels.swift      # UI state management
├── Views/                  # SwiftUI user interface
│   ├── ContentView.swift   # Main tabbed interface
│   ├── TradingView.swift   # Trading interface
│   ├── WalletView.swift    # Portfolio management
│   ├── BARKView.swift      # Governance monitoring
│   └── SettingsView.swift  # App configuration
├── Resources/              # Static resources
│   ├── config.json         # Runtime configuration
│   └── bark-directives.json # BARK protocol definitions
└── Tests/                  # Unit and integration tests
```

## Requirements

- **iOS**: 14.0+
- **Xcode**: 12.5+
- **Swift**: 5.5+
- **Gemini Account**: Required for trading operations

## Setup Instructions

### 1. Clone and Setup Project
```bash
git clone <repository-url>
cd GeminiAxiomApp
open GeminiAxiomApp.xcodeproj
```

### 2. Configure Gemini API Keys
1. Create a Gemini account (sandbox for development)
2. Generate API credentials in the Gemini dashboard
3. The app will prompt for credentials on first launch
4. Keys are securely stored in iOS Keychain

### 3. BARK Protocol Configuration
The BARK protocol runs automatically with preconfigured directives. For custom governance:
1. Edit `Resources/bark-directives.json`
2. Configure operator permissions and protocol definitions

### 4. Certificate Setup
For production deployment, add SSL certificates to the bundle:
1. Place `gemini-prod.cer` and `gemini-sandbox.cer` in `Resources/`
2. Certificate pinning automatically handles SSL validation

## Environment Configuration

### Sandbox (Development)
```swift
let environment: Environment = .sandbox
let isDebugMode = true
```

### Production
```swift
let environment: Environment = .production
let isDebugMode = false
```

Switch environments in `AppConfig.swift` before building.

## BARK Protocol

The BARK protocol provides multi-dimensional governance:

### Core Components
- **Directives**: Protocol definitions, enforcement orders, state transitions, audit requests
- **Dimensions**: Technical, regulatory, ontological, epistemological, economic governance
- **Cryptography**: Ed25519 signatures with SHA3-256 hashing
- **Audit Trail**: Immutable log with remote synchronization

### Example Directive
```json
{
  "type": "PROTOCOL_DEFINITION",
  "operator": "axiomhive:operator:alexis_m_adams",
  "dimensions": ["technical", "regulatory"],
  "constraints": {
    "max_order_size": "1000000",
    "rate_limits": true
  }
}
```

## Security Considerations

- **API Keys**: Never commit to version control; use iOS Keychain
- **Certificates**: Rotate regularly for certificate pinning
- **Private Keys**: Generated per-device for BARK operations
- **Network**: All requests use TLS 1.3 with certificate validation
- **Storage**: Sensitive data encrypted using hardware security

## Testing

```bash
swift test
# Or use Xcode's Test Navigator
```

Run tests in sandbox mode to avoid real trading operations.

## Building for Distribution

### Development
```bash
xcodebuild -scheme GeminiAxiomApp -sdk iphonesimulator -configuration Debug build
```

### Release
```bash
xcodebuild -scheme GeminiAxiomApp -sdk iphoneos -configuration Release archive
```

## Compliance and Audit

The app maintains complete audit trails for:
- All API requests and responses
- Directive execution events
- Authentication attempts
- Trading operations
- Governance state changes

Audit logs sync to configurable remote endpoints for compliance monitoring.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Run tests and linting
4. Submit a pull request

## License

Copyright © 2025 AxiomHive. All rights reserved.

## Support

For support, security issues, or compliance questions:
- Email: security@axiomhive.io
- Documentation: [Internal Wiki]

---

**Status**: Production-Ready
**Version**: 1.0
**Author**: Alexis M Adams
**Organization**: AxiomHive
**Classification**: PRODUCTION-READY
