import PeekeyCore
import SwiftUI

struct AccountCard: View {
    let account: Account
    let date: Date
    let isSelected: Bool
    let isCopied: Bool

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let palette = Palette.palette(for: account)
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 8) {
                Text(account.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                CountdownRing(period: account.period)
            }
            if !account.displaySubtitle.isEmpty {
                Text(account.displaySubtitle)
                    .font(.system(size: 13))
                    .opacity(0.92)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Text(Self.group(account.code(at: date)))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .padding(.top, 4)
                .contentTransition(.numericText())
                .animation(.snappy, value: account.code(at: date))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.gradient)
        .overlay(alignment: .bottomTrailing) {
            if hovering && !isCopied {
                Label(L("Click to copy", "点击复制"), systemImage: "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(12)
                    .transition(.opacity)
            }
        }
        .overlay {
            if isCopied {
                ZStack {
                    Color.black.opacity(0.18)
                    Label(L("Copied", "已复制"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                    .padding(2)
            }
        }
        .shadow(color: palette.end.opacity(hovering ? 0.45 : 0.28), radius: hovering ? 14 : 10, y: hovering ? 7 : 5)
        .offset(y: hovering && !reduceMotion ? -2 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hovering)
        .onHover { h in
            hovering = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("\(account.displayTitle) \(account.displaySubtitle), code \(account.code(at: date).map(String.init).joined(separator: " "))", "\(account.displayTitle) \(account.displaySubtitle)，验证码 \(account.code(at: date).map(String.init).joined(separator: " "))"))
        .accessibilityHint(L("Click to copy", "点击复制"))
        .accessibilityAddTraits(.isButton)
    }

    /// "949761" → "949 761", "12345678" → "1234 5678"
    static func group(_ code: String) -> String {
        guard code.count >= 6 else { return code }
        let mid = code.index(code.startIndex, offsetBy: code.count / 2)
        return String(code[..<mid]) + " " + String(code[mid...])
    }
}

struct CountdownRing: View {
    let period: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { ctx in
            let remaining = TOTP.secondsRemaining(period: period, time: ctx.date)
            let urgent = remaining <= 5
            ZStack {
                Circle()
                    .fill(urgent ? Color.white : Color.clear)
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: remaining / Double(period))
                    .stroke(urgent ? Color.red : Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 18, height: 18)
            .opacity(urgent && !reduceMotion && Int(remaining * 2) % 2 == 0 ? 0.75 : 1)
            .help(L("Refreshes in \(Int(remaining.rounded(.up))) s", "\(Int(remaining.rounded(.up))) 秒后刷新"))
        }
    }
}
