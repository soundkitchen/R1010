import Foundation

struct SuperColliderPaths: Equatable {
    let appBundleURL: URL?
    let sclangURL: URL
    let scsynthURL: URL
    let sourceDescription: String

    var appBundlePath: String? {
        appBundleURL?.path
    }

    var sclangPath: String {
        sclangURL.path
    }

    var scsynthPath: String {
        scsynthURL.path
    }
}
