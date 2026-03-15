import AppKit
import Foundation

@MainActor
final class AppBootstrapCoordinator {
    private let locator: SuperColliderLocator
    private let alertPresenter: DependencyAlertPresenter

    init(
        locator: SuperColliderLocator = SuperColliderLocator(),
        alertPresenter: DependencyAlertPresenter = DependencyAlertPresenter()
    ) {
        self.locator = locator
        self.alertPresenter = alertPresenter
    }

    func resolvePaths() throws -> SuperColliderPaths {
        try locator.locate()
    }

    func handleLaunchFailure(_ error: Error) {
        let details = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription

        switch error {
        case is SuperColliderLocator.LocatorError:
            alertPresenter.presentMissingDependencyAlert(details: details)
        default:
            alertPresenter.presentRuntimeInitializationAlert(details: details)
        }

        NSApp.terminate(nil)
    }
}
