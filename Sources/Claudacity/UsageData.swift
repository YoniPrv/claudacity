import Foundation

struct UsageData {
    let percentage: Double
    let resetsAt: Date?
    let planName: String

    var timeUntilReset: String? {
        guard let resetsAt = resetsAt else { return nil }
        let seconds = Int(resetsAt.timeIntervalSinceNow)
        guard seconds > 0 else { return "Now" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    var resetTimeString: String? {
        guard let resetsAt = resetsAt else { return nil }
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: resetsAt)
    }

    var icon: String {
        switch percentage {
        case ..<25: return "○"
        case ..<50: return "◔"
        case ..<75: return "◑"
        case ..<90: return "◕"
        default: return "●"
        }
    }

    var iconIndex: Int {
        switch percentage {
        case ..<25: return 0
        case ..<50: return 1
        case ..<75: return 2
        case ..<90: return 3
        default: return 4
        }
    }
}

struct Organization: Codable {
    let uuid: String
    let capabilities: [String]?

    var planName: String {
        capabilities?.first { $0.hasPrefix("claude_") }
            .map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
            ?? "Claude"
    }
}
