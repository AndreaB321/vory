import SwiftUI
import VoryCore

/// Add / edit a gateway. Nothing is pre-filled; Save requires a passing Test Connection.
struct GatewayFormView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var existing: GatewayConnection?
    var onSaved: ((GatewayConnection) -> Void)?

    @State private var name = ""
    @State private var urlText = ""
    @State private var pathPrefix = ""
    @State private var authMode: AuthMode = .sessionToken
    @State private var sessionToken = ""
    @State private var username = ""
    @State private var password = ""
    @State private var providerName = ""
    @State private var providers: [AuthProvider] = []
    @State private var cfClientId = ""
    @State private var cfClientSecret = ""
    @State private var bearerSecrets: GatewaySecrets?
    @State private var steps: [ConnectionTestStep] = []
    @State private var testing = false
    @State private var testPassed = false
    @State private var testedVersion: String?
    @State private var errorMessage: String?
    @State private var signingIn = false
    @State private var authClient = NativeAuthClient()

    private var normalizedURL: GatewayURL? { try? GatewayURL.normalize(urlText, pathPrefix: pathPrefix) }
    private var urlError: String? {
        guard !urlText.isEmpty else { return nil }
        do { _ = try GatewayURL.normalize(urlText, pathPrefix: pathPrefix); return nil } catch { return error.localizedDescription }
    }
    private var access: CloudflareAccess { CloudflareAccess(clientId: cfClientId.trimmingCharacters(in: .whitespaces), clientSecret: cfClientSecret.trimmingCharacters(in: .whitespaces)) }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name, prompt: Text("Home"))
                    .accessibilityIdentifier("gateway.name")
                TextField("Gateway URL", text: $urlText, prompt: Text("https://hermes.example.com"))
                    .keyboardType(.URL).textContentType(.URL).autocorrectionDisabled().textInputAutocapitalization(.never)
                    .accessibilityIdentifier("gateway.url")
                TextField("Path prefix (optional)", text: $pathPrefix, prompt: Text("/hermes"))
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
            } header: {
                Text("Gateway")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Enter the URL of your Hermes dashboard (`hermes serve`), not a chat-webui or SSH app. Reverse-proxy path prefixes are supported.")
                    if let urlError { Text(urlError).foregroundStyle(.red) }
                    else if let u = normalizedURL {
                        Text("Will connect to \(u.description)").foregroundStyle(.secondary)
                        if !u.isTLS && !u.isPrivateHost { Text("This is plain HTTP to a public host; credentials will travel unencrypted.").foregroundStyle(.orange) }
                    }
                }
            }

            Section("Authentication") {
                Picker("Method", selection: $authMode) {
                    ForEach(AuthMode.allCases) { Text($0.title).tag($0) }
                }
                switch authMode {
                case .sessionToken:
                    SecureField("Session token", text: $sessionToken)
                        .textContentType(.password).autocorrectionDisabled()
                        .accessibilityIdentifier("gateway.sessionToken")
                    Text("The dashboard's HERMES_DASHBOARD_SESSION_TOKEN. Used when the gateway has no auth gate (loopback / trusted network).")
                        .font(.footnote).foregroundStyle(.secondary)
                case .password:
                    providerPicker
                    TextField("Username", text: $username).textContentType(.username).autocorrectionDisabled().textInputAutocapitalization(.never)
                    SecureField("Password", text: $password).textContentType(.password)
                    Text("The password is exchanged for a session and never stored.").font(.footnote).foregroundStyle(.secondary)
                case .oauth:
                    providerPicker
                    Button {
                        Task { await signInWithBrowser() }
                    } label: {
                        HStack {
                            Label(bearerSecrets == nil ? "Sign in with browser" : "Signed in", systemImage: bearerSecrets == nil ? "safari" : "checkmark.circle.fill")
                            if signingIn { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(normalizedURL == nil || signingIn)
                    Text("Opens the system browser against this gateway's /auth/native/authorize (PKCE). Tokens are stored in the Keychain.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section {
                TextField("CF-Access-Client-Id", text: $cfClientId).autocorrectionDisabled().textInputAutocapitalization(.never)
                SecureField("CF-Access-Client-Secret", text: $cfClientSecret)
            } header: {
                Text("Cloudflare Access (Advanced, optional)")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Leave blank if there is no Cloudflare Access in front of your gateway. When both are set they are sent on every request and on the WebSocket handshake. Safari cookies do not carry over to the app.")
                    if access.isPartiallyConfigured { Text("Enter both the Client ID and the Client Secret, or leave both blank.").foregroundStyle(.red) }
                }
            }

            Section {
                Button {
                    Task { await runTest() }
                } label: {
                    HStack {
                        Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        if testing { ProgressView() }
                        else if testPassed { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                    }
                }
                .disabled(!canTest || testing)
                .accessibilityIdentifier("gateway.test")
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 10) {
                        stepIcon(step.status)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title).font(.subheadline)
                            switch step.status {
                            case .passed(let s): Text(s).font(.footnote).foregroundStyle(.secondary)
                            case .failed(let s): Text(s).font(.footnote).foregroundStyle(.red).textSelection(.enabled)
                            default: EmptyView()
                            }
                        }
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
            } footer: {
                Text("Checks that /api/status returns JSON (not an HTML login page), that your credentials are accepted, and that the WebSocket at /api/ws opens.")
            }
        }
        .navigationTitle(existing == nil ? "Add Gateway" : "Edit Gateway")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(!testPassed || name.trimmingCharacters(in: .whitespaces).isEmpty).accessibilityIdentifier("gateway.save") }
        }
        .onChange(of: urlText) { _, _ in invalidate() }
        .onChange(of: pathPrefix) { _, _ in invalidate() }
        .onChange(of: authMode) { _, _ in invalidate(); Task { await loadProviders() } }
        .onChange(of: sessionToken) { _, _ in invalidate() }
        .onChange(of: cfClientId) { _, _ in invalidate() }
        .onChange(of: cfClientSecret) { _, _ in invalidate() }
        .task { loadExisting(); await loadProviders() }
    }

    private var providerPicker: some View {
        Group {
            if providers.isEmpty {
                TextField("Provider name", text: $providerName, prompt: Text(authMode == .password ? "basic" : "nous"))
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
            } else {
                Picker("Provider", selection: $providerName) {
                    ForEach(providers.filter { authMode == .password ? ($0.supportsPassword ?? false) : true }) { p in
                        Text(p.displayName ?? p.name).tag(p.name)
                    }
                }
            }
        }
    }

    @ViewBuilder private func stepIcon(_ s: ConnectionTestStep.Status) -> some View {
        switch s {
        case .pending: Image(systemName: "circle").foregroundStyle(.tertiary)
        case .running: ProgressView().controlSize(.small)
        case .passed: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    private var canTest: Bool {
        guard normalizedURL != nil, !access.isPartiallyConfigured else { return false }
        switch authMode {
        case .sessionToken: return !sessionToken.isEmpty
        case .password: return !username.isEmpty && !password.isEmpty
        case .oauth: return bearerSecrets != nil
        }
    }

    private func invalidate() { testPassed = false; steps = [] }

    private func loadExisting() {
        guard let c = existing else { return }
        name = c.name
        urlText = c.gateway.description
        authMode = c.authMode
        providerName = c.authProvider ?? ""
        let s = model.store.secrets(for: c.id)
        sessionToken = s.sessionToken ?? ""
        cfClientId = s.access.clientId
        cfClientSecret = s.access.clientSecret
        if s.bearer != nil { bearerSecrets = s }
    }

    private func loadProviders() async {
        guard authMode != .sessionToken, let u = normalizedURL else { return }
        if let p = try? await NativeAuthClient.providers(gateway: u, access: access), !p.isEmpty {
            providers = p
            if providerName.isEmpty || !p.contains(where: { $0.name == providerName }) {
                providerName = p.first(where: { authMode == .password ? ($0.supportsPassword ?? false) : true })?.name ?? p[0].name
            }
        }
    }

    private func signInWithBrowser() async {
        guard let u = normalizedURL else { return }
        signingIn = true; defer { signingIn = false }
        errorMessage = nil
        do {
            bearerSecrets = try await authClient.signInWithBrowser(gateway: u, provider: providerName.isEmpty ? nil : providerName, access: access)
            invalidate()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildSecrets() async throws -> GatewaySecrets {
        var s = GatewaySecrets()
        s.access = access
        switch authMode {
        case .sessionToken:
            s.sessionToken = sessionToken.trimmingCharacters(in: .whitespacesAndNewlines)
        case .password:
            if let b = bearerSecrets, b.bearer != nil, username.isEmpty { s = b; s.access = access; break }
            guard let u = normalizedURL else { throw GatewayURLError.invalid }
            let provider = providerName.isEmpty ? "basic" : providerName
            s = try await NativeAuthClient.signInWithPassword(gateway: u, provider: provider, username: username, password: password, access: access)
            bearerSecrets = s
        case .oauth:
            guard var b = bearerSecrets else { throw NativeAuthError.noCallback }
            b.access = access
            s = b
        }
        return s
    }

    private func runTest() async {
        guard let u = normalizedURL else { return }
        testing = true; testPassed = false; errorMessage = nil
        defer { testing = false }
        do {
            let secrets = try await buildSecrets()
            let conn = GatewayConnection(id: existing?.id ?? UUID(), name: name, gateway: u, authMode: authMode, authProvider: providerName.isEmpty ? nil : providerName)
            let outcome = await ConnectionTester.run(connection: conn, secrets: secrets) { s in Task { @MainActor in steps = s } }
            steps = outcome.steps
            testPassed = outcome.succeeded
            testedVersion = outcome.version
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        guard let u = normalizedURL else { return }
        Task {
            do {
                let secrets = try await buildSecrets()
                var conn = existing ?? GatewayConnection(name: name, gateway: u, authMode: authMode)
                conn.name = name.trimmingCharacters(in: .whitespaces)
                conn.gateway = u
                conn.authMode = authMode
                conn.authProvider = providerName.isEmpty ? nil : providerName
                conn.lastVersion = testedVersion
                try model.store.upsert(conn, secrets: secrets)
                if model.runtime?.connection.id == conn.id { await model.deactivate() }
                onSaved?(conn)
                dismiss()
                await model.activate(conn)
            } catch let e as KeychainError {
                errorMessage = "Could not save to the Keychain (\(e.localizedDescription)). On a simulator this usually means the build is unsigned."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
