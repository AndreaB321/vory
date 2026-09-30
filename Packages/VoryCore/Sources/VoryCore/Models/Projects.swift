import Foundation

/// A Hermes project: a name over one or more folders on the gateway. A chat belongs to a
/// project through its working directory (the gateway's `projects.tree` says which), and a
/// new chat joins one by starting in its primary folder. Keys arrive in snake case and are
/// converted by the shared decoder.
public struct Project: Codable, Hashable, Identifiable, Sendable {
    public struct Folder: Codable, Hashable, Sendable {
        public var path: String
        public var label: String?
        public var isPrimary: Bool?
    }
    public var id: String
    public var slug: String?
    public var name: String
    public var description: String?
    public var icon: String?
    public var color: String?
    public var primaryPath: String?
    public var archived: Bool?
    public var createdAt: Double?
    public var folders: [Folder]?

    public var isArchived: Bool { archived ?? false }
    /// The folder a new chat starts in.
    public var startPath: String? { primaryPath ?? folders?.first(where: { $0.isPrimary == true })?.path ?? folders?.first?.path }
    /// The hue (0…1) from the gateway's `hsl(…)` colour, when it set one.
    public var hue: Double? {
        guard let c = color, let open = c.firstIndex(of: "(") else { return nil }
        let digits = c[c.index(after: open)...].prefix { $0.isNumber || $0 == "." }
        guard let n = Double(digits) else { return nil }
        return n.truncatingRemainder(dividingBy: 360) / 360
    }
}

public struct ProjectsListResponse: Codable, Sendable {
    public var projects: [Project]
    public var activeId: String?
}

/// One node of `projects.tree`, reduced to what the app needs: which stored sessions sit in it.
/// The gateway also lists auto groups (a git root nobody made a project of) and a Home bucket.
public struct ProjectTreeNode: Codable, Sendable {
    public var id: String
    public var label: String?
    public var isAuto: Bool?
    public var isNoProject: Bool?
    public var sessionIds: [String]?
}

public struct ProjectsTreeResponse: Codable, Sendable {
    public var projects: [ProjectTreeNode]
}
