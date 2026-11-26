import PeekeyCore
import SwiftUI

struct CardPalette: Identifiable {
    let key: String
    let name: String
    let start: Color
    let end: Color
    var id: String { key }
    var gradient: LinearGradient {
        LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum Palette {
    static let all: [CardPalette] = [
        .init(key: "green", name: "绿", start: hex(0x7DBE74), end: hex(0x5FA35A)),
        .init(key: "blue", name: "蓝", start: hex(0x5FA8F0), end: hex(0x3B76D6)),
        .init(key: "purple", name: "紫", start: hex(0xA78BFA), end: hex(0x7C5CE0)),
        .init(key: "orange", name: "橙", start: hex(0xF8B163), end: hex(0xEE8A3A)),
        .init(key: "pink", name: "粉", start: hex(0xF48FB1), end: hex(0xE0618E)),
        .init(key: "teal", name: "青", start: hex(0x4FD1C5), end: hex(0x2BA39A)),
        .init(key: "indigo", name: "靛", start: hex(0x7F8CF5), end: hex(0x5560D9)),
        .init(key: "red", name: "红", start: hex(0xF28B82), end: hex(0xD95B52)),
        .init(key: "slate", name: "灰", start: hex(0x8FA3B8), end: hex(0x61768C)),
        .init(key: "gold", name: "金", start: hex(0xE8C55A), end: hex(0xC9A12E)),
    ]

    static func palette(for account: Account) -> CardPalette {
        if let key = account.color, let p = all.first(where: { $0.key == key }) { return p }
        // Stable djb2 hash (String.hashValue is randomized per launch).
        var h: UInt32 = 5381
        for b in account.displayTitle.lowercased().utf8 { h = (h &* 33) &+ UInt32(b) }
        return all[Int(h % UInt32(all.count))]
    }

    private static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
