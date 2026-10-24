import SwiftUI
import AuthenticationServices

/// Email, optional sources, then a traveler-reviewed profile. Guest use remains available.
@MainActor
struct AccountSetupView: View {
    @Environment(\.dismiss) private var dismiss
    let isSettings: Bool
    let onComplete: () -> Void
    @State private var account = EmailAccountService.shared
    @State private var authorization = GoogleAccountAuthorization()
    @State private var stage: Stage = .email
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var usesPassword = false
    @State private var capabilities: TravelerHarnessClient.Capabilities?
    @State private var profile: TravelerHarnessClient.Profile?
    @State private var displayName = ""
    @State private var homeCity = ""
    @State private var interests = ""
    @State private var allowsCalendar = false
    @State private var allowsMail = false
    @State private var aiConsent = false
    @State private var working = false
    @State private var notice: String?
    @State private var isError = false
    @State private var suggestion: String?
    @State private var task: Task<Void, Never>?
    private let client = TravelerHarnessClient()

    private enum Stage: Int { case email, connections, profile, welcome }

    init(isSettings: Bool = false, onComplete: @escaping () -> Void = {}) {
        self.isSettings = isSettings
        self.onComplete = onComplete
    }

    var body: some View {
        Group {
            if stage == .welcome { CompanionWelcomeView(onContinue: onComplete) }
            else { setupContent }
        }
        .tint(CompanionHomeStyle.accent)
        .background(CompanionHomeStyle.paper.ignoresSafeArea())
        .interactiveDismissDisabled(!isSettings)
        .task {
            if let identity = account.identity {
                email = identity.email
                stage = isSettings ? .profile : .connections
                await loadProfile()
            }
            capabilities = try? await client.capabilities()
        }
        .onDisappear { task?.cancel(); password = ""; code = "" }
    }

    private var setupContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack {
                    Text(accountText("account.step.\(stage.rawValue)"))
                        .font(.caption.weight(.semibold)).tracking(1.5)
                        .foregroundStyle(CompanionHomeStyle.secondaryInk)
                    Spacer()
                    if !isSettings {
                        Button(accountText("account.later")) { stage = .welcome }
                            .font(.subheadline).disabled(working || account.isWorking)
                            .accessibilityIdentifier("account.later")
                    }
                }.padding(.top, 28)

                VStack(alignment: .leading, spacing: 12) {
                    Text(accountText("account.title.\(stage.rawValue)"))
                        .font(.system(.largeTitle, design: .serif)).fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(accountText("account.subtitle.\(stage.rawValue)"))
                        .font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk).lineSpacing(5)
                }
                switch stage {
                case .email: emailFields
                case .connections: connectionFields
                case .profile: profileFields
                case .welcome: EmptyView()
                }
                if let notice {
                    Text(notice).font(.footnote).lineSpacing(4)
                        .foregroundStyle(isError ? Color.red : CompanionHomeStyle.secondaryInk)
                        .accessibilityIdentifier("account.notice")
                        .accessibilityAddTraits(.updatesFrequently)
                }
                if let suggestion {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(accountText("account.suggestion.title")).font(.headline)
                        Text(suggestion).font(.subheadline).lineSpacing(5).textSelection(.enabled)
                        Text(accountText("account.suggestion.disclosure")).font(.footnote).foregroundStyle(.secondary)
                    }.padding(20).background(CompanionHomeStyle.incoming, in: RoundedRectangle(cornerRadius: 20))
                        .accessibilityIdentifier("account.suggestion")
                }
            }.padding(.horizontal, 28).padding(.bottom, 28).frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { footer }
        .foregroundStyle(CompanionHomeStyle.ink)
        .navigationTitle(isSettings ? accountText("account.settings.title") : "")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emailFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            inputLabel("account.email")
            TextField(accountText("account.email.placeholder"), text: $email)
                .textContentType(.emailAddress).keyboardType(.emailAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .accountInput().accessibilityIdentifier("account.email")
                .disabled(account.codeSentTo != nil || working)
            if usesPassword {
                SecureField(accountText("account.password"), text: $password)
                    .textContentType(.password).accountInput().accessibilityIdentifier("account.password")
            } else if account.codeSentTo != nil {
                Text(accountText("account.code.sent")).font(.footnote).foregroundStyle(.secondary)
                TextField(accountText("account.code"), text: $code)
                    .textContentType(.oneTimeCode).keyboardType(.numberPad)
                    .accountInput().accessibilityIdentifier("account.code")
                HStack(spacing: 20) {
                    Button(accountText("account.changeEmail")) {
                        account.resetCode(); code = ""; notice = nil
                    }.accessibilityIdentifier("account.changeEmail")
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Button(accountText("account.resendCode")) {
                            run { try await account.requestCode(email: email); code = "" }
                        }.disabled(context.date.timeIntervalSince(account.lastCodeSentAt ?? .distantPast) < 60)
                    }
                }.font(.subheadline).disabled(working || account.isWorking)
            }
            Button(accountText(usesPassword ? "account.useCode" : "account.usePassword")) {
                account.resetCode(); usesPassword.toggle(); notice = nil; password = ""; code = ""
            }.font(.subheadline).disabled(working || account.isWorking)
            Text(accountText("account.email.disclosure")).font(.footnote)
                .foregroundStyle(CompanionHomeStyle.secondaryInk).lineSpacing(5)
        }
    }

    private var connectionFields: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let connection = profile?.google, connection.connected {
                Label(accountText("account.google.connected"), systemImage: "checkmark.circle")
                Text(connection.email).font(.subheadline).textSelection(.enabled)
            } else {
                Toggle(isOn: $allowsCalendar) {
                    sourceLabel("calendar", title: "account.calendar", detail: "account.calendar.detail")
                }.accessibilityIdentifier("account.calendar")
                Divider()
                Toggle(isOn: $allowsMail) {
                    sourceLabel("envelope", title: "account.mail", detail: "account.mail.detail")
                }.accessibilityIdentifier("account.mail")
                Button(accountText("account.google.connect")) { run { try await connectGoogle() } }
                    .buttonStyle(.bordered).controlSize(.large)
                    .disabled(capabilities?.google != true || (!allowsMail && !allowsCalendar) || working)
                    .accessibilityIdentifier("account.google.connect")
                if capabilities?.google != true {
                    Text(accountText("account.google.unavailable")).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Text(accountText("account.google.disclosure")).font(.footnote).foregroundStyle(.secondary).lineSpacing(5)
        }
    }

    private var profileFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let identity = account.identity {
                Label(identity.email, systemImage: "checkmark.seal").font(.subheadline)
                    .accessibilityIdentifier("account.verifiedEmail")
            }
            inputLabel("account.name")
            TextField(accountText("account.name.placeholder"), text: $displayName)
                .textContentType(.nickname).accountInput().accessibilityIdentifier("account.name")
            inputLabel("account.city")
            TextField(accountText("account.city.placeholder"), text: $homeCity)
                .accountInput().accessibilityIdentifier("account.city")
            inputLabel("account.interests")
            TextField(accountText("account.interests.placeholder"), text: $interests, axis: .vertical)
                .lineLimit(2...4).accountInput().accessibilityIdentifier("account.interests")
            Text(accountText("account.profile.source")).font(.footnote).foregroundStyle(.secondary)
            Divider().padding(.vertical, 6)
            Toggle(accountText("account.ai.consent"), isOn: $aiConsent)
                .font(.subheadline).accessibilityIdentifier("account.ai.consent")
            Text(accountText("account.ai.disclosure")).font(.footnote).foregroundStyle(.secondary).lineSpacing(5)
            Button(accountText("account.suggest")) {
                run {
                    try await saveProfile()
                    suggestion = try await client.ask(accountText("account.suggest.prompt")).reply
                }
            }.disabled(!aiConsent || profile == nil || capabilities?.deepseek != true || working)
                .accessibilityIdentifier("account.suggest")
            if isSettings {
                Button(accountText("account.sources.manage")) { stage = .connections; notice = nil }
                    .accessibilityIdentifier("account.sources.manage")
                if profile?.google.connected == true {
                    Button(accountText("account.google.disconnect"), role: .destructive) {
                        run {
                            let result = try await client.disconnectGoogle()
                            await loadProfile()
                            notice = accountText(result.provider_revocation_confirmed
                                ? "account.google.disconnected" : "account.google.disconnectedLocal")
                        }
                    }.accessibilityIdentifier("account.google.disconnect")
                }
                Button(accountText("account.signOut"), role: .destructive) {
                    run {
                        await account.signOut()
                        profile = nil; displayName = ""; homeCity = ""; interests = ""; aiConsent = false
                        email = ""; password = ""; suggestion = nil; stage = .email
                    }
                }.accessibilityIdentifier("account.signOut")
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                switch stage {
                case .email: run { try await authenticate() }
                case .connections: stage = .profile; notice = nil
                case .profile:
                    run {
                        try await saveProfile()
                        if isSettings { dismiss() } else { stage = .welcome }
                    }
                case .welcome: onComplete()
                }
            } label: {
                HStack {
                    if working || account.isWorking { ProgressView().tint(CompanionHomeStyle.paper) }
                    Text(primaryTitle).font(.body.weight(.medium))
                }.frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(CompanionHomeStyle.paper)
                    .background(CompanionHomeStyle.ink, in: Capsule())
            }.disabled(working || account.isWorking || (stage == .profile && profile == nil))
                .accessibilityIdentifier("account.continue")
            if stage == .email && !isSettings {
                Button(accountText("account.guest")) { stage = .welcome }
                    .font(.subheadline).disabled(working || account.isWorking)
                    .accessibilityIdentifier("account.guest")
            } else if stage == .profile && profile == nil {
                Button(accountText("account.retry")) { run { await loadProfile() } }
            }
        }.padding(.horizontal, 28).padding(.vertical, 18).frame(maxWidth: 560).frame(maxWidth: .infinity)
            .background(CompanionHomeStyle.paper)
    }

    private var primaryTitle: String {
        switch stage {
        case .email: return accountText(usesPassword ? "account.signIn" : (account.codeSentTo == nil ? "account.sendCode" : "account.verify"))
        case .connections: return accountText(profile?.google.connected == true ? "account.next" : "account.google.skip")
        case .profile: return accountText(isSettings ? "account.save" : "account.saveContinue")
        case .welcome: return accountText("account.next")
        }
    }

    private func inputLabel(_ key: String) -> some View { Text(accountText(key)).font(.subheadline.weight(.medium)) }

    private func sourceLabel(_ symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title3).frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(accountText(title)).font(.headline)
                Text(accountText(detail)).font(.footnote).foregroundStyle(.secondary).lineSpacing(3)
            }
        }
    }

    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !working else { return }
        notice = nil; isError = false; working = true
        task = Task { @MainActor in
            defer { working = false; task = nil }
            do { try await operation() }
            catch is CancellationError { }
            catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
                notice = accountText("account.google.cancelled")
            } catch {
                isError = true
                notice = (error as? LocalizedError)?.errorDescription ?? accountText("harness.error.unavailable")
            }
        }
    }

    private func authenticate() async throws {
        if usesPassword { try await account.signIn(email: email, password: password); password = "" }
        else if account.codeSentTo != nil { try await account.verifyCode(code); code = "" }
        else { try await account.requestCode(email: email); return }
        stage = .connections
        await loadProfile()
    }

    private func loadProfile() async {
        do {
            let value = try await client.profile()
            profile = value; displayName = value.display_name; homeCity = value.home_city
            interests = value.interests.joined(separator: ", "); aiConsent = value.ai_context_consent
        } catch {
            isError = true
            notice = (error as? LocalizedError)?.errorDescription ?? accountText("harness.error.unavailable")
        }
    }

    private func saveProfile() async throws {
        guard profile != nil else { throw TravelerHarnessClient.Failure.unavailable }
        let values = interests.replacingOccurrences(of: "，", with: ",").split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        profile = try await client.save(.init(display_name: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            home_city: homeCity.trimmingCharacters(in: .whitespacesAndNewlines), interests: values, ai_context_consent: aiConsent))
        notice = accountText("account.saved")
    }

    private func connectGoogle() async throws {
        let result = try await client.startGoogle(calendar: allowsCalendar, mail: allowsMail)
        try await authorization.authorize(result.authorization_url)
        await loadProfile()
        guard profile?.google.connected == true else { throw TravelerHarnessClient.Failure.unavailable }
        notice = accountText("account.google.connected")
    }
}

private extension View {
    func accountInput() -> some View {
        padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(CompanionHomeStyle.incoming, in: RoundedRectangle(cornerRadius: 14))
    }
}
