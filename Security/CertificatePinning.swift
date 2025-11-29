import Foundation
import Security

class CertificatePinning: NSObject, URLSessionDelegate {
    static let shared = CertificatePinning()

    private let pinnedCertificates: [SecCertificate] = {
        let certNames = ["gemini-prod", "gemini-sandbox"]
        var certs: [SecCertificate] = []

        for certName in certNames {
            if let certPath = Bundle.main.path(forResource: certName, ofType: "cer"),
               let certData = try? Data(contentsOf: URL(fileURLWithPath: certPath)),
               let cert = SecCertificateCreateWithData(nil, certData as CFData) {
                certs.append(cert)
            }
        }

        return certs
    }()

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        var secResult = SecTrustResultType.invalid
        let status = SecTrustEvaluate(serverTrust, &secResult)

        guard status == errSecSuccess else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let certificateCount = SecTrustGetCertificateCount(serverTrust)

        for i in 0..<certificateCount {
            if let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) {
                for pinnedCert in pinnedCertificates {
                    if certificate == pinnedCert {
                        let credential = URLCredential(trust: serverTrust)
                        completionHandler(.useCredential, credential)
                        return
                    }
                }
            }
        }

        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}
