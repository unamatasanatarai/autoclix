import Foundation

public enum AppVersion {
    public static var current: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !version.isEmpty {
            return version
        }
        if let path = Bundle.main.path(forResource: "VERSION", ofType: nil),
           let content = try? String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !content.isEmpty {
            return content
        }
        return "1.0.0"
    }
}
