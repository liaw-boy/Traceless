import Foundation

public struct ResidualItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let path: String
    public var size: Int64
    public let category: ResidualCategory
    public var isSelected: Bool
    public let isProtected: Bool
    public let isFolder: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        size: Int64 = 0,
        category: ResidualCategory,
        isSelected: Bool = true,
        isProtected: Bool = false
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.path = PathUtils.abbreviatingWithTilde(url: url)
        self.size = size
        self.category = category
        self.isSelected = isSelected
        self.isProtected = isProtected

        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        self.isFolder = isDir.boolValue
    }

    public var formattedSize: String {
        FileSizeFormatter.format(size)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    public static func == (lhs: ResidualItem, rhs: ResidualItem) -> Bool {
        lhs.url == rhs.url
    }
}
