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
    // Tuned so white text clears WCAG 3:1 (large/bold) at the light end and ~4.7:1+ at the dark end.
    static let all: [CardPalette] = [
        .init(key: "green", name: "绿", start: hex(0x3FA15A), end: hex(0x25804A)),
        .init(key: "blue", name: "蓝", start: hex(0x3D8AF0), end: hex(0x2459D0)),
        .init(key: "purple", name: "紫", start: hex(0x8E6BF0), end: hex(0x6440D4)),
        .init(key: "orange", name: "橙", start: hex(0xE5762B), end: hex(0xC4501C)),
        .init(key: "pink", name: "粉", start: hex(0xE0508A), end: hex(0xBC2F6A)),
        .init(key: "teal", name: "青", start: hex(0x13958C), end: hex(0x0B7069)),
        .init(key: "indigo", name: "靛", start: hex(0x5D6CE8), end: hex(0x3D44C4)),
        .init(key: "red", name: "红", start: hex(0xE0524A), end: hex(0xBA332D)),
        .init(key: "slate", name: "灰", start: hex(0x64788F), end: hex(0x46586C)),
        .init(key: "gold", name: "金", start: hex(0xBE8A12), end: hex(0x956A08)),
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

enum Theme {
    /// Lighter, airier than `windowBackgroundColor` (#ECECEC) so the colored cards carry the UI.
    static let background = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.118, green: 0.118, blue: 0.125, alpha: 1)
            : NSColor(red: 0.969, green: 0.973, blue: 0.980, alpha: 1)
    })
}
