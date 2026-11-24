//
//  InstallAppDialog.swift
//  SideStore
//
//  Created by Magesh K on 8/2/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import UIKit

public enum AppImportSourceMode: String, CaseIterable, Identifiable, Sendable {
    case prompt = "prompt"
    case files  = "files"
    case url    = "url"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .prompt:
            return "每次询问导入方式"
        case .files:
            #if !os(tvOS)
            return "直接从「文件」选择"
            #else
            return "局域网网页上传"
            #endif
        case .url:
            return "从 URL 链接下载"
        }
    }
}

@MainActor
public enum InstallAppDialog {
    
    public static func presentSourceSelection(
        from presentingVC: UIViewController,
        barButtonItem: UIBarButtonItem? = nil,
        mode: AppImportSourceMode = UserDefaults.standard.appImportSourceMode,
        onChooseFiles: @escaping () -> Void,
        onConfirm: @escaping (URL) -> Void
    ) {
        switch mode {
        case .prompt:
            #if !os(tvOS)
            let alertController = UIAlertController(
                title: NSLocalizedString("安装应用", comment: ""),
                message: nil,
                preferredStyle: .actionSheet
            )
            if let popover = alertController.popoverPresentationController {
                popover.barButtonItem = barButtonItem
            }
            alertController.addAction(UIAlertAction(title: NSLocalizedString("从「文件」中选择 IPA", comment: ""), style: .default) { _ in
                onChooseFiles()
            })
            #else
            let alertController = UIAlertController(
                title: NSLocalizedString("安装应用", comment: ""),
                message: NSLocalizedString("请选择 IPA 安装来源：", comment: ""),
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: NSLocalizedString("局域网网页上传", comment: ""), style: .default) { _ in
                onChooseFiles()
            })
            #endif
            
            alertController.addAction(UIAlertAction(title: NSLocalizedString("从网络链接 (URL) 安装", comment: ""), style: .default) { _ in
                self.presentURLInputDialog(from: presentingVC, onConfirm: onConfirm)
            })
            alertController.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
            
            presentingVC.present(alertController, animated: true)

        case .files:
            onChooseFiles()

        case .url:
            self.presentURLInputDialog(from: presentingVC, onConfirm: onConfirm)
        }
    }
    
    private static func presentURLInputDialog(
        from presentingVC: UIViewController,
        onConfirm: @escaping (URL) -> Void
    ) {
        let alert = UIAlertController(
            title: NSLocalizedString("从网络链接 (URL) 安装", comment: ""),
            message: NSLocalizedString("请输入要下载侧载的 .ipa 直链地址：", comment: ""),
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "https://example.com/app.ipa"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.clearButtonMode = .whileEditing
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("继续", comment: ""), style: .default) { _ in
            guard let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let url = URL(string: text),
                  let scheme = url.scheme?.lowercased(),
                  (scheme == "http" || scheme == "https") else {
                let errorAlert = UIAlertController(
                    title: NSLocalizedString("无效的 URL 链接", comment: ""),
                    message: NSLocalizedString("请输入合法的 http:// 或 https:// 链接地址。", comment: ""),
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: NSLocalizedString("好", comment: ""), style: .default))
                presentingVC.present(errorAlert, animated: true)
                return
            }
            
            self.present(ipaURL: url, from: presentingVC) {
                onConfirm(url)
            }
        })
        
        presentingVC.present(alert, animated: true)
    }
    
    public static func present(
        ipaURL: URL,
        from presentingViewController: UIViewController? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        let message: String
        if ipaURL.isFileURL {
            let appName = ipaURL.deletingPathExtension().lastPathComponent
            message = String(format: NSLocalizedString("确定要继续安装「%@」吗？", comment: ""), appName)
        } else {
            message = String(format: NSLocalizedString("确定要从以下地址下载并安装应用吗？\n%@", comment: ""), ipaURL.absoluteString)
        }
        
        self.presentConfirmation(
            message: message,
            from: presentingViewController,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }
    
    public static func present(
        storeApp: StoreApp,
        from presentingViewController: UIViewController? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        let message = String(format: NSLocalizedString("确定要继续安装「%@」吗？", comment: ""), storeApp.name)
        self.presentConfirmation(
            message: message,
            from: presentingViewController,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }

    public static func present(
        installedApp: InstalledApp,
        from presentingViewController: UIViewController? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        let message = String(format: NSLocalizedString("确定要重新覆盖安装「%@」吗？", comment: ""), installedApp.name)
        self.presentConfirmation(
            message: message,
            from: presentingViewController,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }
    
    private static func presentConfirmation(
        message: String,
        from presentingViewController: UIViewController?,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        guard UserDefaults.standard.isInstallConfirmationEnabled else {
            onConfirm()
            return
        }
        
        let rootVC = presentingViewController ?? UIApplication.shared.topViewController()
        guard let presentingVC = rootVC else {
            onCancel()
            return
        }
        
        let alert = UIAlertController(
            title: NSLocalizedString("安装应用", comment: ""),
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("安装", comment: ""), style: .default) { _ in
            onConfirm()
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel) { _ in
            onCancel()
        })
        
        presentingVC.present(alert, animated: true)
    }
}
