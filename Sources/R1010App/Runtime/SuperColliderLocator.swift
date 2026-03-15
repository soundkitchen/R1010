import Foundation

struct SuperColliderLocator {
    enum LocatorError: LocalizedError {
        case incompleteEnvironmentOverride
        case invalidEnvironmentOverride(paths: [String])
        case notFound(searchLocations: [String])

        var errorDescription: String? {
            switch self {
            case .incompleteEnvironmentOverride:
                return "環境変数 override を使う場合は R1010_SCLANG_PATH と R1010_SCSYNTH_PATH の両方が必要です。"
            case .invalidEnvironmentOverride(let paths):
                return "環境変数で指定された SuperCollider 実体が利用できません: \(paths.joined(separator: ", "))"
            case .notFound(let searchLocations):
                let joined = searchLocations.joined(separator: "\n")
                return """
                sclang / scsynth を見つけられませんでした。探索先:
                \(joined)
                """
            }
        }
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func locate() throws -> SuperColliderPaths {
        if let override = try resolveEnvironmentOverride() {
            return override
        }

        for candidate in appBundleCandidates() {
            let resolved = paths(fromAppBundleAt: candidate)
            if isExecutable(resolved.sclangURL) && isExecutable(resolved.scsynthURL) {
                return resolved
            }
        }

        for candidate in directBinaryCandidates() {
            if isExecutable(candidate.sclangURL) && isExecutable(candidate.scsynthURL) {
                return candidate
            }
        }

        throw LocatorError.notFound(searchLocations: searchLocations())
    }

    private func resolveEnvironmentOverride() throws -> SuperColliderPaths? {
        let environment = ProcessInfo.processInfo.environment
        let sclang = environment["R1010_SCLANG_PATH"]
        let scsynth = environment["R1010_SCSYNTH_PATH"]

        if sclang == nil && scsynth == nil {
            return nil
        }

        guard let sclang, let scsynth else {
            throw LocatorError.incompleteEnvironmentOverride
        }

        let resolved = SuperColliderPaths(
            appBundleURL: nil,
            sclangURL: URL(fileURLWithPath: sclang),
            scsynthURL: URL(fileURLWithPath: scsynth),
            sourceDescription: "environment override"
        )

        guard isExecutable(resolved.sclangURL), isExecutable(resolved.scsynthURL) else {
            throw LocatorError.invalidEnvironmentOverride(paths: [sclang, scsynth])
        }

        return resolved
    }

    private func appBundleCandidates() -> [URL] {
        var urls: [URL] = []
        let homeDirectory = fileManager.homeDirectoryForCurrentUser

        urls.append(URL(fileURLWithPath: "/Applications/SuperCollider.app"))
        urls.append(homeDirectory.appendingPathComponent("Applications/SuperCollider.app"))
        urls.append(contentsOf: caskroomBundles(root: "/opt/homebrew/Caskroom/supercollider"))
        urls.append(contentsOf: caskroomBundles(root: "/usr/local/Caskroom/supercollider"))

        var deduplicated: [URL] = []
        var seen = Set<String>()

        for url in urls {
            let standardized = url.standardizedFileURL
            if seen.insert(standardized.path).inserted {
                deduplicated.append(standardized)
            }
        }

        return deduplicated
    }

    private func caskroomBundles(root: String) -> [URL] {
        let rootURL = URL(fileURLWithPath: root, isDirectory: true)
        guard let versions = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return versions
            .filter { isDirectory($0) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedDescending }
            .map { $0.appendingPathComponent("SuperCollider.app", isDirectory: true) }
    }

    private func directBinaryCandidates() -> [SuperColliderPaths] {
        ["/opt/homebrew/bin", "/usr/local/bin"].map { base in
            SuperColliderPaths(
                appBundleURL: nil,
                sclangURL: URL(fileURLWithPath: base).appendingPathComponent("sclang"),
                scsynthURL: URL(fileURLWithPath: base).appendingPathComponent("scsynth"),
                sourceDescription: base
            )
        }
    }

    private func paths(fromAppBundleAt appURL: URL) -> SuperColliderPaths {
        SuperColliderPaths(
            appBundleURL: appURL,
            sclangURL: appURL.appendingPathComponent("Contents/MacOS/sclang"),
            scsynthURL: appURL.appendingPathComponent("Contents/Resources/scsynth"),
            sourceDescription: appURL.path
        )
    }

    private func searchLocations() -> [String] {
        [
            "R1010_SCLANG_PATH / R1010_SCSYNTH_PATH",
            "/Applications/SuperCollider.app",
            "\(fileManager.homeDirectoryForCurrentUser.path)/Applications/SuperCollider.app",
            "/opt/homebrew/Caskroom/supercollider/*/SuperCollider.app",
            "/usr/local/Caskroom/supercollider/*/SuperCollider.app",
            "/opt/homebrew/bin/{sclang,scsynth}",
            "/usr/local/bin/{sclang,scsynth}"
        ]
    }

    private func isExecutable(_ url: URL) -> Bool {
        fileManager.isExecutableFile(atPath: url.path)
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}
