import Foundation
import Security

class UsageService {
    private var sessionKey: String?
    private var orgId: String?
    private var planName = "Claude"
    private static let keychainService = "com.local.claudacity"
    private static let keychainAccount = "sessionKey"

    enum Err: Error, LocalizedError {
        case noKey, network(String), parse

        var errorDescription: String? {
            switch self {
            case .noKey: return "No session key"
            case .network(let s): return "Network: \(s)"
            case .parse: return "Parse error"
            }
        }

        var helpSteps: [String]? {
            if case .noKey = self {
                return ["Click 'Set Session Key...'", "Get from: claude.ai > Cmd+Opt+I > Storage > Cookies"]
            }
            return nil
        }
    }

    func setKey(_ key: String) {
        sessionKey = key
        orgId = nil
        saveToKeychain(key)
    }

    private func saveToKeychain(_ key: String) {
        let data = key.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        var newItem = query
        newItem[kSecValueData as String] = data
        SecItemAdd(newItem as CFDictionary, nil)
    }

    private func loadFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else { return nil }
        return key
    }

    func fetch() async throws -> UsageData {
        if sessionKey == nil {
            sessionKey = loadFromKeychain()
        }
        guard let key = sessionKey, !key.isEmpty else { throw Err.noKey }

        if orgId == nil {
            let (data, _) = try await request("https://claude.ai/api/organizations", key: key)
            guard let org = (try? JSONDecoder().decode([Organization].self, from: data))?.first else { throw Err.parse }
            orgId = org.uuid
            planName = org.planName
        }

        let (data, _) = try await request("https://claude.ai/api/organizations/\(orgId!)/usage", key: key)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fiveHour = json["five_hour"] as? [String: Any] else { throw Err.parse }

        let pct = fiveHour["utilization"] as? Double ?? 0
        var reset: Date?
        if let str = fiveHour["resets_at"] as? String {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            reset = f.date(from: str)
        }
        return UsageData(percentage: pct, resetsAt: reset, planName: planName)
    }

    private func request(_ urlString: String, key: String) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: URL(string: urlString)!)
        req.setValue("sessionKey=\(key)", forHTTPHeaderField: "Cookie")
        req.setValue("Mozilla/5.0 (Macintosh)", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw Err.network("Invalid") }
        if http.statusCode == 401 || http.statusCode == 403 { sessionKey = nil; throw Err.noKey }
        guard http.statusCode == 200 else { throw Err.network("HTTP \(http.statusCode)") }
        return (data, http)
    }
}
