import AppKit
import Foundation

@MainActor
final class DependencyAlertPresenter {
    func presentMissingDependencyAlert(details: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "SuperCollider is required"
        alert.informativeText = """
        R-1010 の起動に必要な SuperCollider を見つけられませんでした。
        SuperCollider が未インストールの場合は、公式ダウンロードまたは Homebrew の "brew install --cask supercollider" を利用してください。

        \(details)
        """
        alert.addButton(withTitle: "Quit")
        alert.runModal()
    }

    func presentRuntimeInitializationAlert(details: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "SuperCollider runtime could not start"
        alert.informativeText = """
        R-1010 は SuperCollider を見つけましたが、ランタイムの起動または初期化に失敗しました。
        インストール有無ではなく、起動時エラーの可能性があります。

        \(details)
        """
        alert.addButton(withTitle: "Quit")
        alert.runModal()
    }
}
