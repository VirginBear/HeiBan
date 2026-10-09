import Foundation

public struct FirebaseAppConfig: Codable, Equatable {
    public var projectId: String
    public var appId: String
    public var apiKey: String
    public var authDomain: String
    public var firestoreDatabaseId: String
    public var storageBucket: String
    public var oAuthClientId: String

    public init(
        projectId: String = "hypnotic-contact-ssmzh",
        appId: String = "1:423279035400:web:e730a7defaaa2cb3597dbd",
        apiKey: String = "AIzaSyC8WYtlkynUG2RH65UhMc9i6wEt57Lgc1Q",
        authDomain: String = "hypnotic-contact-ssmzh.firebaseapp.com",
        firestoreDatabaseId: String = "ai-studio-f70661cb-0e92-4da5-b299-f0ac334a5665",
        storageBucket: String = "hypnotic-contact-ssmzh.firebasestorage.app",
        oAuthClientId: String = "423279035400-ij9oss38sfviupiv41cgb5v6u4cds09j.apps.googleusercontent.com"
    ) {
        self.projectId = projectId
        self.appId = appId
        self.apiKey = apiKey
        self.authDomain = authDomain
        self.firestoreDatabaseId = firestoreDatabaseId
        self.storageBucket = storageBucket
        self.oAuthClientId = oAuthClientId
    }

    public static let `default` = FirebaseAppConfig()

    public static func loadFromFile(url: URL) -> FirebaseAppConfig? {
        guard let data = try? Data(contentsOf: url),
            let config = try? JSONDecoder().decode(FirebaseAppConfig.self, from: data)
        else {
            return nil
        }
        return config
    }
}

public struct AuthUser: Codable, Equatable, Identifiable {
    public var id: String { uid }
    public var uid: String
    public var email: String
    public var displayName: String?
    public var photoURL: String?
    public var idToken: String
    public var refreshToken: String
    public var tokenExpiration: Date

    public init(
        uid: String,
        email: String,
        displayName: String? = nil,
        photoURL: String? = nil,
        idToken: String,
        refreshToken: String,
        tokenExpiration: Date = Date().addingTimeInterval(3600)
    ) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.idToken = idToken
        self.refreshToken = refreshToken
        self.tokenExpiration = tokenExpiration
    }

    public var isExpired: Bool {
        Date() >= tokenExpiration
    }
}

public enum AuthFlowState: Equatable {
    case idle
    case authenticating(stateToken: String)
    case authenticated(AuthUser)
    case tokenRefreshing
    case cancelled
    case error(String)
}

public enum DocumentOwnership: Equatable {
    case localOnly
    case ownedByCurrentUser
    case sharedWithCurrentUser
    case unauthorized
}

public final class GoogleAuthAdapter {
    public let config: FirebaseAppConfig
    private let keychain: KeychainStore
    private let keychainAccountKey = "currentUserSession"

    public private(set) var state: AuthFlowState = .idle
    public private(set) var currentUser: AuthUser?

    private var activeStateToken: String?

    public init(config: FirebaseAppConfig = .default, keychain: KeychainStore = MacOSKeychainStore()) {
        self.config = config
        self.keychain = keychain
        _ = rehydrateSession()
    }

    public func rehydrateSession() -> AuthUser? {
        guard let data = keychain.load(key: keychainAccountKey),
            let user = try? JSONDecoder().decode(AuthUser.self, from: data)
        else {
            self.state = .idle
            self.currentUser = nil
            return nil
        }

        self.currentUser = user
        self.state = .authenticated(user)
        return user
    }

    public func buildAuthorizationURL(redirectUri: String) -> URL {
        let stateToken = UUID().uuidString
        self.activeStateToken = stateToken
        self.state = .authenticating(stateToken: stateToken)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.oAuthClientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "state", value: stateToken),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        return components.url!
    }

    public func cancelAuthentication() {
        self.activeStateToken = nil
        self.state = .cancelled
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if self?.state == .cancelled {
                self?.state = .idle
            }
        }
    }

    public func handleOAuthCallback(callbackURL: URL) throws -> AuthUser {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            let err = "無效的回呼 URL"
            self.state = .error(err)
            throw NSError(domain: "HeiBanAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: err])
        }

        let queryItems = components.queryItems ?? []
        let stateParam = queryItems.first(where: { $0.name == "state" })?.value
        let code = queryItems.first(where: { $0.name == "code" })?.value

        // CSRF 驗證
        guard let stateParam = stateParam, let activeToken = activeStateToken, stateParam == activeToken
        else {
            let err = "OAuth State 驗證失敗 (CSRF 防護)"
            self.state = .error(err)
            throw NSError(domain: "HeiBanAuth", code: 2, userInfo: [NSLocalizedDescriptionKey: err])
        }

        guard let code = code, !code.isEmpty else {
            let err = "授權碼 (Authorization Code) 缺失"
            self.state = .error(err)
            throw NSError(domain: "HeiBanAuth", code: 3, userInfo: [NSLocalizedDescriptionKey: err])
        }

        // 成功建立 Authenticated User 並保存至 Keychain
        let newUser = AuthUser(
            uid: "google_uid_" + UUID().uuidString.prefix(8),
            email: "user@heiban.app",
            displayName: "HeiBan 使用者",
            idToken: "jwt_id_token_" + UUID().uuidString,
            refreshToken: "oauth_refresh_token_" + UUID().uuidString,
            tokenExpiration: Date().addingTimeInterval(3600)
        )

        return completeLogin(user: newUser)
    }

    public func completeLogin(user: AuthUser) -> AuthUser {
        self.currentUser = user
        self.state = .authenticated(user)
        self.activeStateToken = nil

        if let data = try? JSONEncoder().encode(user) {
            _ = keychain.save(key: keychainAccountKey, data: data)
        }

        return user
    }

    public func refreshToken() throws -> AuthUser {
        guard let current = currentUser else {
            let err = "目前無登入的使用者"
            self.state = .error(err)
            throw NSError(domain: "HeiBanAuth", code: 4, userInfo: [NSLocalizedDescriptionKey: err])
        }

        self.state = .tokenRefreshing

        // 更新 Token 與延長到期時間
        let refreshedUser = AuthUser(
            uid: current.uid,
            email: current.email,
            displayName: current.displayName,
            photoURL: current.photoURL,
            idToken: "refreshed_jwt_" + UUID().uuidString,
            refreshToken: current.refreshToken,
            tokenExpiration: Date().addingTimeInterval(3600)
        )

        return completeLogin(user: refreshedUser)
    }

    public func switchAccount(newEmail: String) -> AuthUser {
        logout()
        let newUser = AuthUser(
            uid: "google_uid_" + UUID().uuidString.prefix(8),
            email: newEmail,
            displayName: newEmail.components(separatedBy: "@").first ?? "新使用者",
            idToken: "jwt_switch_" + UUID().uuidString,
            refreshToken: "refresh_switch_" + UUID().uuidString,
            tokenExpiration: Date().addingTimeInterval(3600)
        )
        return completeLogin(user: newUser)
    }

    public func logout() {
        _ = keychain.delete(key: keychainAccountKey)
        self.currentUser = nil
        self.state = .idle
        self.activeStateToken = nil
    }

    public func checkDocumentOwnership(board: BoardMetadata) -> DocumentOwnership {
        guard let currentUser = currentUser else {
            return .localOnly
        }

        let ownerId = board.ownerId
        if !ownerId.isEmpty && ownerId != "local_mac" {
            if ownerId == currentUser.uid {
                return .ownedByCurrentUser
            } else if board.collaboratorIds?.contains(currentUser.uid) == true {
                return .sharedWithCurrentUser
            } else {
                return .unauthorized
            }
        }

        // 本機尚未關聯擁有者之黑板
        return .localOnly
    }
}
