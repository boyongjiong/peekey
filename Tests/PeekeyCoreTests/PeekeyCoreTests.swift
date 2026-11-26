import Foundation
@testable import PeekeyCore
import XCTest

final class TOTPTests: XCTestCase {
    // RFC 6238 Appendix B
    let sha1Seed = Data("12345678901234567890".utf8)
    let sha256Seed = Data("12345678901234567890123456789012".utf8)
    let sha512Seed = Data("1234567890123456789012345678901234567890123456789012345678901234".utf8)

    func testRFC6238Vectors() {
        let cases: [(TimeInterval, String, String, String)] = [
            (59, "94287082", "46119246", "90693936"),
            (1111111109, "07081804", "68084774", "25091201"),
            (1111111111, "14050471", "67062674", "99943326"),
            (1234567890, "89005924", "91819424", "93441116"),
            (2000000000, "69279037", "90698825", "38618901"),
            (20000000000, "65353130", "77737706", "47863826"),
        ]
        for (t, s1, s256, s512) in cases {
            let date = Date(timeIntervalSince1970: t)
            XCTAssertEqual(TOTP.code(secret: sha1Seed, time: date, digits: 8, algorithm: .sha1), s1)
            XCTAssertEqual(TOTP.code(secret: sha256Seed, time: date, digits: 8, algorithm: .sha256), s256)
            XCTAssertEqual(TOTP.code(secret: sha512Seed, time: date, digits: 8, algorithm: .sha512), s512)
        }
    }

    func testSixDigitsZeroPadded() {
        let code = TOTP.code(secret: sha1Seed, time: Date(timeIntervalSince1970: 1111111109), digits: 6)
        XCTAssertEqual(code, "081804")
    }

    func testSecondsRemaining() {
        XCTAssertEqual(TOTP.secondsRemaining(period: 30, time: Date(timeIntervalSince1970: 60)), 30)
        XCTAssertEqual(TOTP.secondsRemaining(period: 30, time: Date(timeIntervalSince1970: 89)), 1)
    }
}

final class Base32Tests: XCTestCase {
    func testRoundTrip() {
        let data = Data("12345678901234567890".utf8)
        let encoded = Base32.encode(data)
        XCTAssertEqual(encoded, "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ")
        XCTAssertEqual(Base32.decode(encoded), data)
    }

    func testLenientDecode() {
        XCTAssertEqual(Base32.decode("jbsw y3dp-ehpk 3pxp"), Base32.decode("JBSWY3DPEHPK3PXP"))
        XCTAssertEqual(Base32.decode("MZXW6==="), Data("foo".utf8))
        XCTAssertNil(Base32.decode("not base32 !!"))
        XCTAssertNil(Base32.decode(""))
    }
}

final class OTPAuthURITests: XCTestCase {
    func testParseFull() throws {
        let a = try OTPAuthURI.parse("otpauth://totp/ACME%20Co:john.doe@email.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME%20Co&algorithm=SHA256&digits=8&period=60")
        XCTAssertEqual(a.issuer, "ACME Co")
        XCTAssertEqual(a.name, "john.doe@email.com")
        XCTAssertEqual(a.algorithm, .sha256)
        XCTAssertEqual(a.digits, 8)
        XCTAssertEqual(a.period, 60)
    }

    func testIssuerFromLabel() throws {
        let a = try OTPAuthURI.parse("otpauth://totp/GitHub:me?secret=JBSWY3DPEHPK3PXP")
        XCTAssertEqual(a.issuer, "GitHub")
        XCTAssertEqual(a.name, "me")
        XCTAssertEqual(a.digits, 6)
        XCTAssertEqual(a.period, 30)
    }

    func testNoIssuer() throws {
        let a = try OTPAuthURI.parse("otpauth://totp/me@example.com?secret=JBSWY3DPEHPK3PXP")
        XCTAssertEqual(a.issuer, "")
        XCTAssertEqual(a.displayTitle, "me@example.com")
    }

    func testErrors() {
        XCTAssertThrowsError(try OTPAuthURI.parse("https://example.com")) { XCTAssertEqual($0 as? OTPImportError, .notOTPAuth) }
        XCTAssertThrowsError(try OTPAuthURI.parse("otpauth://hotp/x?secret=JBSWY3DPEHPK3PXP&counter=1")) {
            XCTAssertEqual($0 as? OTPImportError, .unsupportedType("hotp"))
        }
        XCTAssertThrowsError(try OTPAuthURI.parse("otpauth://totp/x")) { XCTAssertEqual($0 as? OTPImportError, .missingSecret) }
        XCTAssertThrowsError(try OTPAuthURI.parse("otpauth://totp/x?secret=!!!")) { XCTAssertEqual($0 as? OTPImportError, .invalidSecret) }
    }

    func testBuildRoundTrip() throws {
        let a = Account(issuer: "Sumsub - cockpit", name: "a+b@x.cn", secret: "JBSWY3DPEHPK3PXP", algorithm: .sha512, digits: 8, period: 45)
        let b = try OTPAuthURI.parse(OTPAuthURI.build(a))
        XCTAssertEqual(b.issuer, a.issuer)
        XCTAssertEqual(b.name, a.name)
        XCTAssertEqual(b.secret, a.secret)
        XCTAssertEqual(b.algorithm, a.algorithm)
        XCTAssertEqual(b.digits, a.digits)
        XCTAssertEqual(b.period, a.period)
    }
}

final class MigrationTests: XCTestCase {
    /// Builds a protobuf payload by hand to test the decoder.
    private func field(_ n: Int, _ wire: Int) -> [UInt8] { [UInt8(n << 3 | wire)] }
    private func bytesField(_ n: Int, _ b: [UInt8]) -> [UInt8] { field(n, 2) + [UInt8(b.count)] + b }

    func testDecode() throws {
        let secret = Array("12345678901234567890".utf8)
        var otp: [UInt8] = []
        otp += bytesField(1, secret)
        otp += bytesField(2, Array("Example:alice@google.com".utf8))
        otp += bytesField(3, Array("Example".utf8))
        otp += field(4, 0) + [1]
        otp += field(5, 0) + [1]
        otp += field(6, 0) + [2]
        var hotp: [UInt8] = bytesField(1, secret) + bytesField(2, Array("h".utf8)) + field(6, 0) + [1]
        hotp += field(7, 0) + [5]
        let payload = bytesField(1, otp) + bytesField(1, hotp) + field(2, 0) + [1]
        let b64 = Data(payload).base64EncodedString()
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let accounts = try OTPAuthURI.parseAny("otpauth-migration://offline?data=\(b64)")
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].issuer, "Example")
        XCTAssertEqual(accounts[0].name, "alice@google.com")
        XCTAssertEqual(accounts[0].secretData, Data(secret))
    }
}
