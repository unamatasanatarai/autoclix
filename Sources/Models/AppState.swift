import Foundation
import Combine

public final class AppState: ObservableObject {
    public static let shared = AppState()
    @Published public var quitNotice: String? = nil
}
