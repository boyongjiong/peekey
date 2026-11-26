import CryptoKit
import Foundation

public enum OTPAlgorithm: String, Codable, CaseIterable, Sendable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"
}

/// RFC 6238 time-based one-time password generator.
public enum TOTP {
    public static func code(
        secret: Data,
        time: Date = Date(),
        period: Int = 30,
        digits: Int = 6,
        algorithm: OTPAlgorithm = .sha1
    ) -> String {
        let counter = UInt64(max(0, time.timeIntervalSince1970) / Double(max(1, period)))
        return hotp(secret: secret, counter: counter, digits: digits, algorithm: algorithm)
    }

    /// RFC 4226 HOTP.
    public static func hotp(secret: Data, counter: UInt64, digits: Int, algorithm: OTPAlgorithm) -> String {
        var bigEndian = counter.bigEndian
        let message = Data(bytes: &bigEndian, count: 8)
        let key = SymmetricKey(data: secret)
        let mac: [UInt8]
        switch algorithm {
        case .sha1: mac = Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        case .sha256: mac = Array(HMAC<SHA256>.authenticationCode(for: message, using: key))
        case .sha512: mac = Array(HMAC<SHA512>.authenticationCode(for: message, using: key))
        }
        let offset = Int(mac[mac.count - 1] & 0x0F)
        let binary = (UInt32(mac[offset] & 0x7F) << 24)
            | (UInt32(mac[offset + 1]) << 16)
            | (UInt32(mac[offset + 2]) << 8)
            | UInt32(mac[offset + 3])
        let d = min(max(digits, 1), 9)
        var modulus: UInt32 = 1
        for _ in 0..<d { modulus *= 10 }
        let value = binary % modulus
        let s = String(value)
        return String(repeating: "0", count: d - s.count) + s
    }

    /// Seconds remaining in the current period.
    public static func secondsRemaining(period: Int, time: Date = Date()) -> Double {
        let p = Double(max(1, period))
        return p - time.timeIntervalSince1970.truncatingRemainder(dividingBy: p)
    }
}
