import Foundation

/// The gateway's projects for the selected bot, and which stored chat sits in which project.
/// Nothing is known until `refresh()` ran: `available` is nil, then false on a gateway whose
/// Hermes has no projects methods (JSON-RPC -32601, the only way to tell), true otherwise.
@MainActor
@Observable
public final class ProjectsStore {
    public private(set) var available: Bool?
    public private(set) var projects: [Project] = []
    public private(set) var activeID: String?
    /// Stored session id → project id, from `projects.tree`. Sessions in the gateway's auto
    /// groups (a git root nobody made a project of) and in its Home bucket are absent.
    public private(set) var membership: [String: String] = [:]
    public private(set) var lastError: String?
    private weak var runtime: GatewayRuntime?
    private var refreshing = false

    public init() {}
    func attach(_ runtime: GatewayRuntime) { self.runtime = runtime }

    public var open: [Project] { projects.filter { !$0.isArchived } }
    public func project(id: String?) -> Project? { id.flatMap { id in projects.first { $0.id == id } } }
    public func project(forSession id: String) -> Project? { project(id: membership[id]) }

    public func refresh() async {
        guard let runtime, !refreshing else { return }
        refreshing = true; defer { refreshing = false }
        do {
            let r: ProjectsListResponse = try await runtime.rpc("projects.list").decode()
            projects = r.projects
            activeID = r.activeId
            available = true
            lastError = nil
            await refreshTree()
        } catch let e as RPCError where e.code == -32601 {
            available = false; projects = []; membership = [:]; activeID = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Which chats are in which project. Cheap; called again when the session list changes.
    public func refreshTree() async {
        guard let runtime, available == true else { return }
        guard let r: ProjectsTreeResponse = try? await runtime.rpc("projects.tree", ["preview_limit": .number(0), "session_limit": .number(2000)]).decode() else { return }
        var m: [String: String] = [:]
        for node in r.projects where node.isNoProject != true && node.isAuto != true {
            for sid in node.sessionIds ?? [] { m[sid] = node.id }
        }
        membership = m
    }

    private func rt() throws -> GatewayRuntime {
        guard let runtime else { throw HermesAPIError.transport("No gateway connected") }
        return runtime
    }

    @discardableResult
    public func create(name: String, folder: String, makeActive: Bool = false) async throws -> Project {
        let r = try await rt().rpc("projects.create", ["name": .string(name), "folders": .array([.string(folder)]), "use": .bool(makeActive)])
        await refresh()
        guard let p = r["project"] else { throw HermesAPIError.decoding("projects.create returned no project") }
        return try p.decode(Project.self)
    }
    public func rename(_ p: Project, to name: String) async throws {
        _ = try await rt().rpc("projects.update", ["id": .string(p.id), "name": .string(name)]); await refresh()
    }
    public func archive(_ p: Project, restore: Bool = false) async throws {
        _ = try await rt().rpc("projects.archive", ["id": .string(p.id), "restore": .bool(restore)]); await refresh()
    }
    public func delete(_ p: Project) async throws {
        _ = try await rt().rpc("projects.delete", ["id": .string(p.id)]); await refresh()
    }
    public func setActive(_ p: Project?) async throws {
        _ = try await rt().rpc("projects.set_active", ["id": p.map { .string($0.id) } ?? .null]); await refresh()
    }
}
