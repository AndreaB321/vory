// Prints a short-lived App Store Connect API token (ES256 JWT) from ASC_KEY_ID, ASC_ISSUER_ID and
// ASC_KEY_PATH in the environment. Used by testflight.sh; run with `swift asc-jwt.swift`.
import CryptoKit
import Foundation

let env = ProcessInfo.processInfo.environment
guard let kid = env["ASC_KEY_ID"], let iss = env["ASC_ISSUER_ID"], let path = env["ASC_KEY_PATH"] else {
    FileHandle.standardError.write(Data("ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH must be set\n".utf8)); exit(1)
}
func b64(_ d: Data) -> String {
    d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}
do {
    let key = try P256.Signing.PrivateKey(pemRepresentation: String(contentsOfFile: path, encoding: .utf8))
    let now = Int(Date().timeIntervalSince1970)
    let header = try JSONSerialization.data(withJSONObject: ["alg": "ES256", "kid": kid, "typ": "JWT"])
    let claims = try JSONSerialization.data(withJSONObject: ["iss": iss, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"])
    let input = b64(header) + "." + b64(claims)
    let sig = try key.signature(for: Data(input.utf8))
    print(input + "." + b64(sig.rawRepresentation))
} catch {
    FileHandle.standardError.write(Data("could not mint token: \(error)\n".utf8)); exit(1)
}
