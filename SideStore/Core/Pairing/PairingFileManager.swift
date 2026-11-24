//
//  PairingFileManager.swift
//  SideStore
//
//  Created by Magesh K on 17/06/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers
import MinimuxerCommon
import CryptoKit

public struct PairingFileMetadata: Sendable {
    public let exists: Bool
    public let size: Int64
    public let creationDate: Date?
    public let modificationDate: Date?
}

final class PairingFileManager: NSObject {
    static let shared = PairingFileManager()

    private let migrationLock = NSLock()
    private static let preinstalledPairingHashDefaultsKey = "zhCNPreinstalledPairingImportedSHA256"
    private static let explicitPairingResetDefaultsKey = "zhCNUserExplicitlyResetPairing"

    private static let remotePairingSpecificKeys: Set<String> = [
        "public_key",
        "private_key",
        "identifier",
        "alt_irk"
    ]

    private static let lockdownSpecificKeys: Set<String> = [
        "WiFiMACAddress",
        "SystemBUID",
        "RootPrivateKey",
        "HostPrivateKey",
        "HostID",
        "RootCertificate",
        "UDID",
        "EscrowBag",
        "HostCertificate",
        "DeviceCertificate"
    ]

    static var supportedContentTypes: [UTType] {
        var types = AppConstants.Pairing.supportedExtensions.compactMap { UTType(filenameExtension: $0) }
        types.append(contentsOf: [.propertyList, .xml])
        return types
    }

    var activeProtocol: PairingProtocol {
        minimuxerPairingProtocol()
    }

    var persistedActiveProtocol: PairingProtocol? {
        get { UserDefaults.standard.activePairingProtocol }
        set { UserDefaults.standard.activePairingProtocol = newValue }
    }

    var preferredProtocol: PairingProtocol? {
        get { UserDefaults.standard.preferredPairingProtocol }
        set { UserDefaults.standard.preferredPairingProtocol = newValue }
    }

    nonisolated func pairingFileURL(for mode: PairingProtocol) -> URL {
        let fileName = mode == .rppairing ? AppConstants.Pairing.remotePairingFileName : AppConstants.Pairing.lockdownPairingFileName
        return FileManager.default.documentsDirectory.appendingPathComponent(fileName)
    }

    nonisolated func hasPairingFile(for mode: PairingProtocol) -> Bool {
        return FileManager.default.fileExists(atPath: pairingFileURL(for: mode).path)
    }

    nonisolated func hasPairingFile() -> Bool {
        guard !UserDefaults.standard.isPairingReset else { return false }
        if let target = preferredProtocol, hasPairingFile(for: target) {
            return true
        }
        if let mode = persistedActiveProtocol, hasPairingFile(for: mode) {
            return true
        }
        return false
    }

    nonisolated func metadata(for mode: PairingProtocol) -> PairingFileMetadata {
        let fileURL = pairingFileURL(for: mode)
        let path = fileURL.path
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            return PairingFileMetadata(exists: false, size: 0, creationDate: nil, modificationDate: nil)
        }
        let attrs = (try? fm.attributesOfItem(atPath: path)) ?? [:]
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let creation = (attrs[.creationDate] as? Date) ?? (attrs[.modificationDate] as? Date)
        let mod = attrs[.modificationDate] as? Date
        return PairingFileMetadata(exists: true, size: size, creationDate: creation, modificationDate: mod)
    }

    nonisolated func fetchPairingFile(for mode: PairingProtocol) -> String? {
        let fileURL = pairingFileURL(for: mode)
        let fm = FileManager.default
        if fm.fileExists(atPath: fileURL.path),
           let contents = try? String(contentsOf: fileURL), !contents.isEmpty 
        {
            return contents
        }
        return nil
    }

    nonisolated func fetchPairingFile(preferred: PairingProtocol? = nil) -> String? {
        guard !UserDefaults.standard.isPairingReset else { return nil }
        let targetPreferred = preferred ?? preferredProtocol
        if let targetPreferred, let contents = fetchPairingFile(for: targetPreferred) {
            return contents
        }
        if let persisted = persistedActiveProtocol {
            return fetchPairingFile(for: persisted)
        }
        return nil
    }
    
    nonisolated func isAmbiguousPairingError(_ error: Error) -> Bool {
        if case PairingError.ambiguous = error {
            return true
        }
        let desc = error.localizedDescription.lowercased()
        return desc.contains("ambiguous")
            || (desc.contains("remote pairing") && desc.contains("lockdown"))
    }

    nonisolated func isDualProtocol(content: String) -> Bool {
        let hasLockdown = (try? PairingFileParser.parse(content: content, preferred: .lockdown)) != nil
        let hasRemoteRP = (try? PairingFileParser.parse(content: content, preferred: .rppairing)) != nil
        return hasLockdown && hasRemoteRP
    }

    nonisolated func resolvedProtocol(for content: String, preferred: PairingProtocol? = nil) -> PairingProtocol? {
        if let preferred, preferred != .unknown {
            return preferred
        }
        do {
            let parsed = try PairingFileParser.parse(content: content, preferred: nil)
            return parsed.mode
        } catch {
            if isAmbiguousPairingError(error) {
                return .lockdown
            }
            return nil
        }
    }

    nonisolated func sanitizedPairingContent(_ content: String, for mode: PairingProtocol) -> String {
        guard mode == .lockdown || mode == .rppairing,
              isDualProtocol(content: content),
              let data = content.data(using: .utf8),
              var dict = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] else {
            return content
        }

        let keysToStrip = (mode == .lockdown) ? Self.remotePairingSpecificKeys : Self.lockdownSpecificKeys
        var didStrip = false
        for key in keysToStrip {
            if dict.removeValue(forKey: key) != nil {
                didStrip = true
            }
        }
        guard didStrip,
              let cleanedData = try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0),
              let cleanedString = String(data: cleanedData, encoding: .utf8),
              let validated = try? PairingFileParser.parse(content: cleanedString, preferred: nil),
              validated.mode == mode else {
            return content
        }

        debugLog("[PairingFile] Sanitized dual-protocol pairing plist for .\(mode.rawValue) protocol.")
        return cleanedString
    }

    @discardableResult
    nonisolated func parse(content: String, preferred: PairingProtocol? = nil) throws -> any PairingFile {
        do {
            return try PairingFileParser.parse(content: content, preferred: preferred)
        } catch {
            // iloader 2.4.2 writes dual-protocol pairing files (10 Lockdown keys + 4 Remote Pairing keys).
            // When no protocol is explicitly preferred, default to .lockdown for LocalDevVPN stability.
            if preferred == nil, isAmbiguousPairingError(error) {
                debugLog("[PairingFile] Dual-protocol pairing file detected; falling back to .lockdown protocol.")
                return try PairingFileParser.parse(content: content, preferred: .lockdown)
            }
            throw error
        }
    }

    @discardableResult
    func savePairingFile(contents: String, preferred: PairingProtocol? = nil) throws -> any PairingFile {
        let parsed = try parse(content: contents, preferred: preferred)
        let normalizedContents = sanitizedPairingContent(contents, for: parsed.mode)
        let finalParsed = (try? parse(content: normalizedContents, preferred: parsed.mode)) ?? parsed
        let destinationURL = pairingFileURL(for: finalParsed.mode)
        let fm = FileManager.default
        if fm.fileExists(atPath: destinationURL.path) {
            try? fm.removeItem(at: destinationURL)
        }
        try normalizedContents.write(to: destinationURL, atomically: true, encoding: .utf8)
        debugLog("[PairingFile] Saved \(finalParsed.mode.rawValue) pairing file to: \(destinationURL.path)")
        UserDefaults.standard.isPairingReset = false
        UserDefaults.standard.set(false, forKey: Self.explicitPairingResetDefaultsKey)
        return finalParsed
    }

    func inspectPairingFile(from url: URL, preferred: PairingProtocol? = nil) throws -> (content: String, file: any PairingFile) {
        let isSecured = url.startAccessingSecurityScopedResource()
        defer {
            if isSecured {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        let parsed = try parse(content: content, preferred: preferred)
        return (content, parsed)
    }

    func importPairingFile(from url: URL, preferred: PairingProtocol? = nil) throws {
        let (content, _) = try inspectPairingFile(from: url, preferred: preferred)
        let parsed = try savePairingFile(contents: content, preferred: preferred)
        persistedActiveProtocol = parsed.mode
    }

    /// Automatically imports `ALTPairingFile.mobiledevicepairing` (e.g. placed by iloader "Place In All Apps")
    /// and repairs/sanitizes any pre-existing dual-protocol pairing files on disk so Onboarding & Boot work seamlessly.
    @discardableResult
    nonisolated func importExternalOrLegacyPairingFileIfNeeded() -> Bool {
        migrationLock.withLock {
            let fm = FileManager.default
            var didImportOrActivate = false

            let legacyURL = fm.documentsDirectory.appendingPathComponent(AppConstants.Pairing.legacyPairingFileName)
            if fm.fileExists(atPath: legacyURL.path),
               let data = try? Data(contentsOf: legacyURL),
               let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
               !content.isEmpty {
                let dual = isDualProtocol(content: content)
                if let primary = try? parse(content: content, preferred: nil) {
                    if (try? savePairingFile(contents: content, preferred: primary.mode)) != nil {
                        if dual {
                            let secondaryMode: PairingProtocol = (primary.mode == .lockdown) ? .rppairing : .lockdown
                            _ = try? savePairingFile(contents: content, preferred: secondaryMode)
                        }
                        if let pref = preferredProtocol, hasPairingFile(for: pref) {
                            persistedActiveProtocol = pref
                        } else {
                            persistedActiveProtocol = primary.mode
                        }
                        try? fm.removeItem(at: legacyURL)
                        debugLog("[PairingFile] Auto-imported external/legacy pairing file (\(primary.mode.rawValue), dual=\(dual)).")
                        didImportOrActivate = true
                    }
                }
            }

            // Sanitize any existing dual-protocol files on disk (e.g. from overwrite upgrade)
            for proto in [PairingProtocol.lockdown, PairingProtocol.rppairing] {
                let url = pairingFileURL(for: proto)
                if fm.fileExists(atPath: url.path),
                   let content = try? String(contentsOf: url, encoding: .utf8),
                   !content.isEmpty,
                   isDualProtocol(content: content) {
                    let cleaned = sanitizedPairingContent(content, for: proto)
                    if cleaned != content {
                        try? cleaned.write(to: url, atomically: true, encoding: .utf8)
                        debugLog("[PairingFile] Sanitized existing dual-protocol file at \(url.lastPathComponent) for .\(proto.rawValue).")
                    }
                }
            }

            // If valid pairing files already exist on disk (e.g. migrated or placed externally)
            // while hasPairingFile() still reports false, activate them automatically.
            if !hasPairingFile() {
                for candidate in [PairingProtocol.lockdown, PairingProtocol.rppairing] {
                    if let content = fetchPairingFile(for: candidate),
                       (try? parse(content: content, preferred: candidate)) != nil {
                        UserDefaults.standard.isPairingReset = false
                        UserDefaults.standard.set(false, forKey: Self.explicitPairingResetDefaultsKey)
                        persistedActiveProtocol = candidate
                        debugLog("[PairingFile] Auto-activated existing \(candidate.rawValue) pairing file on disk.")
                        didImportOrActivate = true
                        break
                    }
                }
            }

            // If still no pairing file in Documents and user has not explicitly reset pairing,
            // load optional app-bundle preinstalled pairing resource (`PreinstalledPairing.plist`).
            if !hasPairingFile(),
               !UserDefaults.standard.bool(forKey: Self.explicitPairingResetDefaultsKey),
               let bundledURL = bundledPreinstalledPairingURL(),
               let bundledData = try? Data(contentsOf: bundledURL),
               let content = String(data: bundledData, encoding: .utf8) ?? String(data: bundledData, encoding: .isoLatin1),
               !content.isEmpty {
                let bundledHash = SHA256.hash(data: bundledData).map { String(format: "%02x", $0) }.joined()
                let previousHash = UserDefaults.standard.string(forKey: Self.preinstalledPairingHashDefaultsKey)
                if previousHash != bundledHash {
                    let dual = isDualProtocol(content: content)
                    if let primary = try? parse(content: content, preferred: nil),
                       (try? savePairingFile(contents: content, preferred: primary.mode)) != nil {
                        if dual {
                            let secondaryMode: PairingProtocol = (primary.mode == .lockdown) ? .rppairing : .lockdown
                            _ = try? savePairingFile(contents: content, preferred: secondaryMode)
                        }
                        if let pref = preferredProtocol, hasPairingFile(for: pref) {
                            persistedActiveProtocol = pref
                        } else {
                            persistedActiveProtocol = primary.mode
                        }
                        UserDefaults.standard.set(bundledHash, forKey: Self.preinstalledPairingHashDefaultsKey)
                        debugLog("[PairingFile] Auto-loaded bundled PreinstalledPairing.plist from \(bundledURL.path) (\(primary.mode.rawValue), dual=\(dual)).")
                        didImportOrActivate = true
                    }
                }
            }

            return didImportOrActivate
        }
    }

    private nonisolated func bundledPreinstalledPairingURL() -> URL? {
        let name = AppConstants.Pairing.preinstalledResourceName
        let ext = AppConstants.Pairing.preinstalledResourceExt

        // 1. Main bundle (standalone SideStore.app or LiveContainer's Frameworks/SideStoreApp.framework)
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }
        // 2. Active host bundle (e.g. LiveContainer.app root when running as built-in SideStore)
        if let url = Bundle.Info.activeBundle.url(forResource: name, withExtension: ext) {
            return url
        }
        // 3. Direct path fallbacks for both standalone and LiveContainer-embedded layouts
        let fileName = "\(name).\(ext)"
        let candidateURLs: [URL] = [
            Bundle.main.bundleURL.appendingPathComponent(fileName),
            Bundle.Info.activeBundleURL.appendingPathComponent(fileName),
            Bundle(for: PairingFileManager.self).bundleURL.appendingPathComponent(fileName),
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(fileName),
        ]
        let fm = FileManager.default
        for candidate in candidateURLs where fm.fileExists(atPath: candidate.path) {
            return candidate
        }
        return nil
    }

    func deletePairingFile(for mode: PairingProtocol) {
        let fileURL = pairingFileURL(for: mode)
        let fm = FileManager.default
        if fm.fileExists(atPath: fileURL.path) {
            try? fm.removeItem(at: fileURL)
            debugLog("[PairingFile] Deleted \(mode.rawValue) pairing file: \(fileURL.path)")
        }
        if mode == persistedActiveProtocol {
            persistedActiveProtocol = nil
        }
    }

    func resetAllPairingFiles() {
        let fm = FileManager.default
        let files = [
            AppConstants.Pairing.lockdownPairingFileName,
            AppConstants.Pairing.remotePairingFileName,
            AppConstants.Pairing.legacyPairingFileName
        ]
        for name in files {
            let path = fm.documentsDirectory.appendingPathComponent(name)
            if fm.fileExists(atPath: path.path) {
                try? fm.removeItem(at: path)
            }
        }
        UserDefaults.standard.isPairingReset = true
        UserDefaults.standard.set(true, forKey: Self.explicitPairingResetDefaultsKey)
        persistedActiveProtocol = nil
        debugLog("[PairingFile] Reset all pairing files.")
    }
}
