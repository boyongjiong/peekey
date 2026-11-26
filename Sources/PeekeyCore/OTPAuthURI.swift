import Foundation

public enum OTPImportError: Error, Equatable, LocalizedError {
    case notOTPAuth
    case unsupportedType(String)
    case missingSecret
    case invalidSecret
    case invalidMigrationPayload

    public var errorDescription: String? {
        switch self {
        case .notOTPAuth: return "Not a valid 2FA QR code (otpauth:// link required)"
        case .unsupportedType(let t): return "\(t.uppercased()) is not supported, only TOTP"
        case .missingSecret: return "The link is missing a secret"
        case .invalidSecret: return "Invalid secret (Base32 expected)"
        case .invalidMigrationPayload: return "Unable to parse Google Authenticator export"
        }
    }
}

public enum OTPAuthURI {
    /// Parses any supported payload: `otpauth://totp/...` or `otpauth-migration://offline?data=...`.
    public static func parseAny(_ string: String) throws -> [Account] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("otpauth-migration://") {
            return try MigrationPayload.parse(uri: trimmed)
        }
        return [try parse(trimmed)]
    }

    /// Parses `otpauth://totp/Issuer:name?secret=...&issuer=...&algorithm=...&digits=...&period=...`
    public static func parse(_ string: String) throws -> Account {
        guard let comps = URLComponents(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
              comps.scheme?.lowercased() == "otpauth" else { throw OTPImportError.notOTPAuth }
        let type = (comps.host ?? "").lowercased()
        guard type == "totp" else { throw OTPImportError.unsupportedType(type.isEmpty ? "unknown" : type) }

        var params: [String: String] = [:]
        for item in comps.queryItems ?? [] {
            params[item.name.lowercased()] = item.value ?? ""
        }
        guard let secret = params["secret"], !secret.isEmpty else { throw OTPImportError.missingSecret }
        guard Base32.decode(secret) != nil else { throw OTPImportError.invalidSecret }

        // Label: "/Issuer:account" (percent-decoded by URLComponents.path)
        var label = comps.path
        if label.hasPrefix("/") { label.removeFirst() }
        var labelIssuer: String?
        var name = label
        if let idx = label.firstIndex(of: ":") {
            labelIssuer = String(label[..<idx]).trimmingCharacters(in: .whitespaces)
            name = String(label[label.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
        }
        let issuer = params["issuer"].flatMap { $0.isEmpty ? nil : $0 } ?? labelIssuer ?? ""

        let algorithm = OTPAlgorithm(rawValue: (params["algorithm"] ?? "SHA1").uppercased()) ?? .sha1
        let digits = Int(params["digits"] ?? "") ?? 6
        let period = Int(params["period"] ?? "") ?? 30

        return Account(
            issuer: issuer,
            name: name,
            secret: secret,
            algorithm: algorithm,
            digits: (6...8).contains(digits) ? digits : 6,
            period: period > 0 ? period : 30
        )
    }

    public static func build(_ account: Account) -> String {
        var comps = URLComponents()
        comps.scheme = "otpauth"
        comps.host = "totp"
        let label = account.issuer.isEmpty ? account.name : "\(account.issuer):\(account.name)"
        comps.path = "/" + label
        var items = [URLQueryItem(name: "secret", value: account.secret)]
        if !account.issuer.isEmpty { items.append(URLQueryItem(name: "issuer", value: account.issuer)) }
        items.append(URLQueryItem(name: "algorithm", value: account.algorithm.rawValue))
        items.append(URLQueryItem(name: "digits", value: String(account.digits)))
        items.append(URLQueryItem(name: "period", value: String(account.period)))
        comps.queryItems = items
        return comps.string ?? ""
    }
}
