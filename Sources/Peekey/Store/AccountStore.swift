import Foundation
import PeekeyCore

final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var loadError: String?

    /// `PEEKEY_DEMO=1` → in-memory sample data, never touches the keychain (for screenshots / UI dev).
    private let demo = ProcessInfo.processInfo.environment["PEEKEY_DEMO"] == "1"

    init() { load() }

    func load() {
        if demo {
            accounts = [
                Account(issuer: "GitHub", name: "octocat@example.com", secret: "JBSWY3DPEHPK3PXP", color: "green"),
                Account(issuer: "Google", name: "me@gmail.com", secret: "GEZDGNBVGY3TQOJQ", color: "blue"),
                Account(issuer: "AWS - production", name: "admin", secret: "MZXW6YTBOI======"),
                Account(issuer: "Cloudflare", name: "ops@example.com", secret: "KRSXG5CTMVRXEZLU"),
            ]
            return
        }
        do {
            if let data = try KeychainVault.load() {
                accounts = try JSONDecoder().decode([Account].self, from: data)
            }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func persist() {
        guard !demo else { return }
        do {
            try KeychainVault.save(try JSONEncoder().encode(accounts))
        } catch {
            loadError = "保存失败：\(error.localizedDescription)"
        }
    }

    /// Adds accounts, skipping duplicates. Returns how many were actually added.
    @discardableResult
    func add(_ new: [Account]) -> Int {
        var added = 0
        for a in new where !accounts.contains(where: { $0.isDuplicate(of: a) }) {
            accounts.append(a)
            added += 1
        }
        if added > 0 { persist() }
        return added
    }

    func update(_ account: Account) {
        guard let i = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[i] = account
        persist()
    }

    func delete(_ id: UUID) {
        accounts.removeAll { $0.id == id }
        persist()
    }

    func move(_ id: UUID, by offset: Int) {
        guard let i = accounts.firstIndex(where: { $0.id == id }) else { return }
        let j = i + offset
        guard accounts.indices.contains(j) else { return }
        accounts.swapAt(i, j)
        persist()
    }
}
