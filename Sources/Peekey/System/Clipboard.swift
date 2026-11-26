import AppKit

enum Clipboard {
    /// Marker type respected by clipboard managers (nspasteboard.org) so codes aren't recorded in history.
    private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    static func copy(_ string: String, clearAfter seconds: Int?) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
        pb.setString(string, forType: concealed)
        let count = pb.changeCount
        guard let seconds, seconds > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds)) {
            // Only clear if the user hasn't copied anything else since.
            if pb.changeCount == count { pb.clearContents() }
        }
    }
}
