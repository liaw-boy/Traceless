import Foundation

public enum ResidualCategory: String, CaseIterable, Identifiable, Sendable {
    case appBundle
    case preferences
    case applicationSupport
    case caches
    case containers
    case groupContainers
    case savedState
    case logs
    case launchAgents
    case webData
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .appBundle:
            return "應用程式本體"
        case .preferences:
            return "偏好設定 (.plist)"
        case .applicationSupport:
            return "應用程式支援資料"
        case .caches:
            return "快取與暫存檔案"
        case .containers:
            return "沙盒容器 (Containers)"
        case .groupContainers:
            return "群組容器 (Group Containers)"
        case .savedState:
            return "應用程式狀態快照"
        case .logs:
            return "日誌與崩潰報告"
        case .launchAgents:
            return "背景排程與啟動項目"
        case .webData:
            return "網頁資料與 Cookies"
        case .other:
            return "其他關聯檔案"
        }
    }

    public var iconName: String {
        switch self {
        case .appBundle:
            return "app.badge"
        case .preferences:
            return "gearshape.2"
        case .applicationSupport:
            return "folder.badge.gearshape"
        case .caches:
            return "bolt.horizontal"
        case .containers:
            return "shippingbox"
        case .groupContainers:
            return "archivebox"
        case .savedState:
            return "clock.arrow.circlepath"
        case .logs:
            return "doc.text.magnifyingglass"
        case .launchAgents:
            return "paperplane"
        case .webData:
            return "network"
        case .other:
            return "doc"
        }
    }

    public var sortOrder: Int {
        switch self {
        case .appBundle: return 0
        case .applicationSupport: return 1
        case .preferences: return 2
        case .caches: return 3
        case .containers: return 4
        case .groupContainers: return 5
        case .savedState: return 6
        case .webData: return 7
        case .logs: return 8
        case .launchAgents: return 9
        case .other: return 10
        }
    }
}
