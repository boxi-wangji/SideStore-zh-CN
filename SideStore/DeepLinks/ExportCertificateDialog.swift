//
//  ExportCertificateDialog.swift
//  SideStore
//
//  Created by Magesh K on 8/2/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import UIKit

@MainActor
public enum ExportCertificateDialog {
    
    public static func present(callbackTemplate: String, presentingViewController: UIViewController? = nil) {
        let rootVC = presentingViewController ?? UIApplication.shared.topViewController()
        guard let presentingVC = rootVC else { return }
        
        let alert = UIAlertController(
            title: NSLocalizedString("导出签名证书", comment: ""),
            message: NSLocalizedString("确定要将你的签名证书导出给外部应用吗？获得证书的应用将能使用你的开发者身份进行签名。", comment: ""),
            preferredStyle: .alert
        )
        
        let exportAction = UIAlertAction(title: NSLocalizedString("导出", comment: ""), style: .default) { _ in
            guard callbackTemplate.contains("$(BASE64_CERT)") else {
                let toast = ToastView(text: NSLocalizedString("回调模板缺少 $(BASE64_CERT) 占位符", comment: ""), detailText: nil)
                toast.show(in: presentingVC)
                return
            }
            
            guard let encodedCert = CertificateManager.shared.activeSigningCertificateBase64Encoded,
                  let password = CertificateManager.shared.activeCertificate?.password else {
                let toast = ToastView(text: NSLocalizedString("未找到可导出的本地签名证书或密钥", comment: ""), detailText: nil)
                toast.show(in: presentingVC)
                return
            }
            
            var urlStr = callbackTemplate.replacingOccurrences(of: "$(BASE64_CERT)", with: encodedCert, options: .literal, range: nil)
            urlStr = urlStr.replacingOccurrences(of: "$(PASSWORD)", with: password, options: .literal, range: nil)
            
            guard let callbackURL = URL(string: urlStr) else {
                let toast = ToastView(text: NSLocalizedString("构造回调 URL 失败！", comment: ""), detailText: nil)
                toast.show(in: presentingVC)
                return
            }
            
            debugLog("[ExportCertificateDialog] Opening certificate callback URL: \(callbackURL.absoluteString)")
            UIApplication.shared.open(callbackURL)
        }
        
        alert.addAction(exportAction)
        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
        
        presentingVC.present(alert, animated: true)
    }
}
