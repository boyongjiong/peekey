import Foundation

public struct Account: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var issuer: String
    public var name: String
    /// Base32-encoded secret (normalized, no padding).
    public var secret: String
    public var algorithm: OTPAlgorithm
    public var digits: Int
    public var period: Int
    /// Palette key; nil → derived from issuer.
    public var color: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        issuer: String,
        name: String,
        secret: String,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        color: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.issuer = issuer
        self.name = name
        self.secret = Base32.normalize(secret)
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
        self.color = color
        self.createdAt = createdAt
    }

    public var secretData: Data? { Base32.decode(secret) }

    public var isValid: Bool { secretData != nil && (6...8).contains(digits) && period > 0 }

    public func code(at time: Date = Date()) -> String {
        guard let data = secretData else { return String(repeating: "-", count: digits) }
        return TOTP.code(secret: data, time: time, period: period, digits: digits, algorithm: algorithm)
    }

    /// Title shown on the card: issuer, falling back to name.
    public var displayTitle: String { issuer.isEmpty ? name : issuer }
    public var displaySubtitle: String { issuer.isEmpty ? "" : name }

    /// Same secret + issuer + name is considered a duplicate.
    public func isDuplicate(of other: Account) -> Bool {
        secret == other.secret && issuer == other.issuer && name == other.name
    }
}
