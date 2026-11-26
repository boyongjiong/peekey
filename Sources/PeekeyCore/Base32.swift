import Foundation

/// RFC 4648 Base32 (alphabet A–Z, 2–7). Decoding is lenient: case-insensitive,
/// ignores whitespace, dashes and trailing `=` padding.
public enum Base32 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)
    private static let decodeTable: [UInt8: UInt8] = {
        var table: [UInt8: UInt8] = [:]
        for (i, c) in alphabet.enumerated() { table[c] = UInt8(i) }
        return table
    }()

    /// Normalizes user input: uppercased, strips spaces / dashes / padding.
    public static func normalize(_ string: String) -> String {
        string.uppercased().filter { !$0.isWhitespace && $0 != "-" && $0 != "=" }
    }

    public static func decode(_ string: String) -> Data? {
        let chars = Array(normalize(string).utf8)
        guard !chars.isEmpty else { return nil }
        var buffer: UInt64 = 0
        var bits = 0
        var out = Data()
        out.reserveCapacity(chars.count * 5 / 8)
        for c in chars {
            guard let v = decodeTable[c] else { return nil }
            buffer = (buffer << 5) | UInt64(v)
            bits += 5
            if bits >= 8 {
                bits -= 8
                out.append(UInt8((buffer >> UInt64(bits)) & 0xFF))
            }
        }
        return out.isEmpty ? nil : out
    }

    public static func encode(_ data: Data) -> String {
        var out = ""
        var buffer: UInt64 = 0
        var bits = 0
        for byte in data {
            buffer = (buffer << 8) | UInt64(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                out.append(Character(UnicodeScalar(alphabet[Int((buffer >> UInt64(bits)) & 0x1F)])))
            }
        }
        if bits > 0 {
            out.append(Character(UnicodeScalar(alphabet[Int((buffer << UInt64(5 - bits)) & 0x1F)])))
        }
        return out
    }
}
