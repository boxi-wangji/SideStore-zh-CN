//
//  PairingViewController.swift
//  SideStore
//
//  Created by Magesh K on 20/09/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import UIKit
import UniformTypeIdentifiers
import MinimuxerCommon

final class PairingViewController: NSObject {
    static let shared = PairingViewController()

    private var completion: ((URL?) -> Void)?

    @MainActor
    func presentPairingFileAlert(on vc: UIViewController, isRetry: Bool, completion: ((URL?) -> Void)? = nil) {
        self.completion = { url in
            completion?(url)
            self.completion = nil
        }
        let title = isRetry ? NSLocalizedString("配对文件无效", comment: "") : NSLocalizedString("配对文件", comment: "")
        let message = isRetry
            ? NSLocalizedString("所选配对文件损坏或格式不受支持，请重新选择有效的配对文件。", comment: "")
            : NSLocalizedString("请选择电脑生成的配对文件，或点击「帮助」查看图文教程。", comment: "")
        
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.setMarkdownMessage(message)
        alert.addAction(UIAlertAction(title: NSLocalizedString("帮助", comment: ""), style: .default) { _ in
            UIApplication.shared.open(AppConstants.URLs.pairingDocumentation)
            if completion == nil {
                sleep(2); exit(0)
            } else {
                completion?(nil)
            }
        })
        #if !os(tvOS)
        alert.addAction(UIAlertAction(title: NSLocalizedString("选择配对文件", comment: ""), style: .default) { _ in
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: PairingFileManager.supportedContentTypes)
            picker.delegate = self
            picker.shouldShowFileExtensions = true
            vc.present(picker, animated: true)
            UserDefaults.standard.isPairingReset = false
        })
        #endif
        
        let cancelTitle = isRetry ? NSLocalizedString("跳过", comment: "") : NSLocalizedString("取消", comment: "")
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
            if completion == nil {
                self.showPairingWarningAndProceed(on: vc)
            } else {
                completion?(nil)
            }
        })
        vc.present(alert, animated: true)
    }

    func showPairingWarningAndProceed(on vc: UIViewController) {
        let warningAlert = UIAlertController(
            title: "⚠️ " + NSLocalizedString("尚未配置配对文件", comment: ""),
            message: nil,
            preferredStyle: .alert
        )
        let warningMessage = NSLocalizedString("未导入有效配对文件前，所有需要连接本机服务的操作（包括**安装**、**刷新**、**重签**应用）均无法运行。", comment: "")
        warningAlert.setMarkdownMessage(warningMessage)
        warningAlert.addAction(UIAlertAction(title: NSLocalizedString("好", comment: ""), style: .default))
        vc.present(warningAlert, animated: true)
    }

    @MainActor
    func presentProtocolMismatchAlert(
        on vc: UIViewController,
        savedPreference: PairingProtocol,
        providedProtocol: PairingProtocol,
        onSwitch: @escaping () -> Void,
        onChooseOther: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        let title = NSLocalizedString("配对文件协议不匹配", comment: "")
        let message = String(
            format: NSLocalizedString("你当前设置的首选协议为 **%@**，但所选配对文件协议为 **%@**。\n\n是否切换并使用 **%@** 协议？", comment: ""),
            savedPreference.rawValue,
            providedProtocol.rawValue,
            providedProtocol.rawValue
        )
        
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.setMarkdownMessage(message)
        alert.addAction(UIAlertAction(title: String(format: NSLocalizedString("切换为 %@", comment: ""), providedProtocol.rawValue), style: .default) { _ in
            onSwitch()
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("重新选择文件", comment: ""), style: .default) { _ in
            onChooseOther()
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel) { _ in
            onCancel()
        })
        vc.present(alert, animated: true)
    }

    @MainActor
    func confirmProtocolMismatchSwitch(
        on vc: UIViewController,
        savedPreference: PairingProtocol,
        providedProtocol: PairingProtocol
    ) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            presentProtocolMismatchAlert(
                on: vc,
                savedPreference: savedPreference,
                providedProtocol: providedProtocol,
                onSwitch: {
                    PairingFileManager.shared.preferredProtocol = providedProtocol
                    PairingFileManager.shared.persistedActiveProtocol = providedProtocol
                    continuation.resume(returning: true)
                },
                onChooseOther: {
                    continuation.resume(returning: false)
                },
                onCancel: {
                    continuation.resume(returning: false)
                }
            )
        }
    }

    @MainActor
    func handlePotentialProtocolMismatch(
        on vc: UIViewController,
        pairingContent: String
    ) async -> Bool {
        guard let saved = PairingFileManager.shared.preferredProtocol else {
            return false
        }
        // Dual-protocol files (e.g. iloader 2.4.2) satisfy the saved preferred protocol without mismatch.
        if (try? PairingFileManager.shared.parse(content: pairingContent, preferred: saved)) != nil {
            return false
        }
        guard let parsed = try? PairingFileManager.shared.parse(content: pairingContent, preferred: nil),
              parsed.mode != saved else {
            return false
        }
        return await confirmProtocolMismatchSwitch(
            on: vc,
            savedPreference: saved,
            providedProtocol: parsed.mode
        )
    }
    @MainActor
    private func finalizeImport(from url: URL) {
        do {
            debugLog("[PairingFile] User picked pairing file from: \(url.path)")
            let targetPreferred: PairingProtocol?
            if let saved = PairingFileManager.shared.preferredProtocol,
               (try? PairingFileManager.shared.inspectPairingFile(from: url, preferred: saved)) != nil {
                targetPreferred = saved
            } else {
                targetPreferred = nil
            }
            try PairingFileManager.shared.importPairingFile(from: url, preferred: targetPreferred)
            self.completion?(url)
        } catch {
            debugLog("[PairingFile] Error importing pairing file: \(error)")
            self.completion?(nil)
        }
    }
}

#if !os(tvOS)
extension PairingViewController: UIDocumentPickerDelegate {
    @MainActor
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            self.completion?(nil)
            controller.dismiss(animated: true, completion: nil)
            return
        }

        let presentingVC = controller.presentingViewController

        let savedPreferred = PairingFileManager.shared.preferredProtocol
        let inspectionResult = (savedPreferred != nil ? (try? PairingFileManager.shared.inspectPairingFile(from: url, preferred: savedPreferred)) : nil)
            ?? (try? PairingFileManager.shared.inspectPairingFile(from: url))

        guard let (content, parsed) = inspectionResult else {
            finalizeImport(from: url)
            controller.dismiss(animated: true, completion: nil)
            return
        }

        controller.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            guard let presenting = presentingVC else {
                self.finalizeImport(from: url)
                return
            }

            Task { @MainActor in
                if await self.handlePotentialProtocolMismatch(on: presenting, pairingContent: content) {
                    self.finalizeImport(from: url)
                } else if PairingFileManager.shared.preferredProtocol == parsed.mode || PairingFileManager.shared.preferredProtocol == nil {
                    self.finalizeImport(from: url)
                } else {
                    self.presentPairingFileAlert(on: presenting, isRetry: true, completion: self.completion)
                }
            }
        }
    }

    @MainActor
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.completion?(nil)
    }
}
#else
extension PairingViewController {
    @MainActor
    func startTVImport(on vc: UIViewController, isRetry: Bool, completion: ((URL?) -> Void)? = nil) {
        self.completion = { url in
            completion?(url)
            self.completion = nil
        }

        let title = isRetry ? NSLocalizedString("配对文件无效", comment: "") : NSLocalizedString("需要配对文件", comment: "")
        TVWebFileTransferManager.shared.startImport(
            acceptedExtensions: AppConstants.Pairing.supportedExtensions,
            title: title,
            presentingVC: vc
        ) { [weak self] tempURL in
            guard let self = self else { return }
            guard let tempURL = tempURL,
                  let (pairingString, _) = try? PairingFileManager.shared.inspectPairingFile(from: tempURL) else {
                if let completion = self.completion {
                    completion(nil)
                } else {
                    self.showPairingWarningAndProceed(on: vc)
                }
                return
            }

            do {
                try PairingFileManager.shared.savePairingFile(contents: pairingString)
                let activeURL = PairingFileManager.shared.pairingFileURL(for: PairingFileManager.shared.activeProtocol)
                if let completion = self.completion {
                    completion(activeURL)
                } else {
                    Task { @MainActor in
                        do {
                            try await AppBootManager.shared.startMinimuxer(pairingFile: pairingString)
                        } catch {
                            debugLog("[PairingFile] startMinimuxer failed: \(error)")
                            if await self.handlePotentialProtocolMismatch(on: vc, pairingContent: pairingString) {
                                do {
                                    try await AppBootManager.shared.startMinimuxer(pairingFile: pairingString)
                                } catch {
                                    debugLog("[PairingFile] startMinimuxer retry after protocol switch failed: \(error)")
                                }
                            }
                        }
                    }
                }
            } catch {
                debugLog("[PairingFile] Failed to save uploaded pairing file: \(error)")
                if let completion = self.completion {
                    completion(nil)
                }
            }
        }
    }
}
#endif

extension UIAlertController {
    func setMarkdownMessage(_ markdown: String) {
        let plainText = markdown
            .replacingOccurrences(of: "***", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "___", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "_", with: "")
        self.message = plainText

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 3

        let baseFont = UIFont.preferredFont(forTextStyle: .footnote)
        let boldDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitBold) ?? baseFont.fontDescriptor
        let boldFont = UIFont(descriptor: boldDescriptor, size: baseFont.pointSize)

        if let attr = try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            let mutable = NSMutableAttributedString(attr)
            mutable.enumerateAttribute(.font, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
                if let font = value as? UIFont, font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    mutable.addAttribute(.font, value: boldFont, range: range)
                } else {
                    mutable.addAttribute(.font, value: baseFont, range: range)
                }
            }
            mutable.addAttributes([
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle
            ], range: NSRange(location: 0, length: mutable.length))
            self.setValue(mutable, forKey: "attributedMessage")
        } else {
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle
            ]
            let attributedMessage = NSAttributedString(string: plainText, attributes: baseAttributes)
            self.setValue(attributedMessage, forKey: "attributedMessage")
        }
    }
}
