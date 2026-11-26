import Foundation

/// Minimal decoder for Google Authenticator export QR codes:
/// `otpauth-migration://offline?data=<base64 protobuf MigrationPayload>`.
///
/// ```
/// message MigrationPayload { repeated OtpParameters otp_parameters = 1; ... }
/// message OtpParameters {
///   bytes secret = 1; string name = 2; string issuer = 3;
///   Algorithm algorithm = 4;  // 1 SHA1, 2 SHA256, 3 SHA512, 4 MD5
///   DigitCount digits = 5;    // 1 SIX, 2 EIGHT
///   OtpType type = 6;         // 1 HOTP, 2 TOTP
///   int64 counter = 7;
/// }
/// ```
public enum MigrationPayload {
    public static func parse(uri: String) throws -> [Account] {
        guard let comps = URLComponents(string: uri),
              comps.scheme?.lowercased() == "otpauth-migration",
              var b64 = comps.queryItems?.first(where: { $0.name == "data" })?.value
        else { throw OTPImportError.invalidMigrationPayload }
        b64 = b64.replacingOccurrences(of: " ", with: "+")
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64.append("=") }
        guard let data = Data(base64Encoded: b64) else { throw OTPImportError.invalidMigrationPayload }
        return try parse(data: data)
    }

    public static func parse(data: Data) throws -> [Account] {
        var reader = ProtoReader(data: data)
        var accounts: [Account] = []
        while let (field, wire) = try reader.nextTag() {
            if field == 1 && wire == 2 {
                let sub = try reader.readBytes()
                if let account = try parseOtp(sub) { accounts.append(account) }
            } else {
                try reader.skip(wire: wire)
            }
        }
        guard !accounts.isEmpty else { throw OTPImportError.invalidMigrationPayload }
        return accounts
    }

    private static func parseOtp(_ data: Data) throws -> Account? {
        var r = ProtoReader(data: data)
        var secret = Data(), name = "", issuer = ""
        var algorithm = OTPAlgorithm.sha1, digits = 6, type: UInt64 = 2
        while let (field, wire) = try r.nextTag() {
            switch (field, wire) {
            case (1, 2): secret = try r.readBytes()
            case (2, 2): name = String(decoding: try r.readBytes(), as: UTF8.self)
            case (3, 2): issuer = String(decoding: try r.readBytes(), as: UTF8.self)
            case (4, 0):
                switch try r.readVarint() {
                case 2: algorithm = .sha256
                case 3: algorithm = .sha512
                default: algorithm = .sha1
                }
            case (5, 0): digits = try r.readVarint() == 2 ? 8 : 6
            case (6, 0): type = try r.readVarint()
            default: try r.skip(wire: wire)
            }
        }
        guard type != 1, !secret.isEmpty else { return nil } // skip HOTP
        if let idx = name.firstIndex(of: ":") {
            let prefix = String(name[..<idx])
            if issuer.isEmpty { issuer = prefix }
            if prefix == issuer { name = String(name[name.index(after: idx)...]).trimmingCharacters(in: .whitespaces) }
        }
        return Account(issuer: issuer, name: name, secret: Base32.encode(secret),
                       algorithm: algorithm, digits: digits, period: 30)
    }
}

struct ProtoReader {
    let bytes: [UInt8]
    var pos = 0
    init(data: Data) { bytes = Array(data) }

    mutating func nextTag() throws -> (Int, Int)? {
        guard pos < bytes.count else { return nil }
        let tag = try readVarint()
        return (Int(tag >> 3), Int(tag & 0x7))
    }

    mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while pos < bytes.count {
            let b = bytes[pos]; pos += 1
            result |= UInt64(b & 0x7F) << shift
            if b & 0x80 == 0 { return result }
            shift += 7
            if shift > 63 { break }
        }
        throw OTPImportError.invalidMigrationPayload
    }

    mutating func readBytes() throws -> Data {
        let len = Int(try readVarint())
        guard len >= 0, pos + len <= bytes.count else { throw OTPImportError.invalidMigrationPayload }
        defer { pos += len }
        return Data(bytes[pos..<pos + len])
    }

    mutating func skip(wire: Int) throws {
        switch wire {
        case 0: _ = try readVarint()
        case 1: pos += 8
        case 2: _ = try readBytes()
        case 5: pos += 4
        default: throw OTPImportError.invalidMigrationPayload
        }
        if pos > bytes.count { throw OTPImportError.invalidMigrationPayload }
    }
}
