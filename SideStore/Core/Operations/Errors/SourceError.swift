//
//  SourceError.swift
//  AltStore
//
//  Created by Riley Testut on 5/3/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

extension SourceError
{
    enum Code: Int, ALTErrorCode
    {
        typealias Error = SourceError
        
        case unsupported
        case duplicateBundleID
        case duplicateVersion
        
        case blocked
        case changedID
        case duplicate
        
        case missingPermissionUsageDescription
        case missingScreenshotSize
        
        case marketplaceNotSupported = 101
        case marketplaceRequired
    }
    
    static func unsupported(_ source: Source) -> SourceError { SourceError(code: .unsupported, source: source) }
    static func duplicateBundleID(_ bundleID: String, source: Source) -> SourceError { SourceError(code: .duplicateBundleID, source: source, bundleID: bundleID) }
    static func duplicateVersion(_ version: String, for app: StoreApp, source: Source) -> SourceError { SourceError(code: .duplicateVersion, source: source, app: app, version: version) }
    
    static func blocked(_ source: Source, bundleIDs: [String]?, existingSource: Source?) -> SourceError { SourceError(code: .blocked, source: source, existingSource: existingSource, bundleIDs: bundleIDs) }
    static func changedID(_ identifier: String, previousID: String, source: Source) -> SourceError { SourceError(code: .changedID, source: source, sourceID: identifier, previousSourceID: previousID) }
    static func duplicate(_ source: Source, existingSource: Source?) -> SourceError { SourceError(code: .duplicate, source: source, existingSource: existingSource) }
    
    static func missingPermissionUsageDescription(for permission: any ALTAppPermission, app: StoreApp, source: Source) -> SourceError {
        SourceError(code: .missingPermissionUsageDescription, source: source, app: app, permission: permission)
    }
    
    static func missingScreenshotSize(for screenshot: AppScreenshot, source: Source) -> SourceError {
        SourceError(code: .missingScreenshotSize, source: source, app: screenshot.app, screenshotURL: screenshot.imageURL)
    }
    
    static func marketplaceNotSupported(source: Source) -> SourceError {
        return SourceError(code: .marketplaceNotSupported, source: source)
    }
    
    static func marketplaceRequired(source: Source) -> SourceError {
        return SourceError(code: .marketplaceRequired, source: source)
    }
}

struct SourceError: ALTLocalizedError
{
    let code: Code
    var errorTitle: String?
    var errorFailure: String?
    
    @Managed var source: Source
    
    @Managed var app: StoreApp?
    @Managed var existingSource: Source?
    var version: String?
    var bundleID: String?
    var bundleIDs: [String]?
        
    // Store in userInfo so they can be viewed from Error Log.
    @UserInfoValue var sourceID: String?
    @UserInfoValue var previousSourceID: String?
    
    @UserInfoValue
    var permission: (any ALTAppPermission)?
    
    @UserInfoValue
    var screenshotURL: URL?
    
    var errorFailureReason: String {
        switch self.code
        {
        case .unsupported: return String(format: NSLocalizedString("当前版本的 SideStore 不支持软件源「%@」的格式。", comment: ""), self.$source.name)
        case .duplicateBundleID:
            let bundleIDFragment = self.bundleID.map { String(format: NSLocalizedString("包名 %@", comment: ""), $0) } ?? NSLocalizedString("相同的 Bundle ID 包名", comment: "")
            let failureReason = String(format: NSLocalizedString("软件源「%@」中包含多个使用%@的应用。", comment: ""), self.$source.name, bundleIDFragment)
            return failureReason
            
        case .duplicateVersion:
            var versionFragment = NSLocalizedString("重复的版本号", comment: "")
            if let version
            {
                versionFragment += " (\(version))"
            }
            
            let appFragment: String
            if let name = self.$app.name, let bundleID = self.$app.bundleIdentifier
            {
                appFragment = name + " (\(bundleID))"
            }
            else
            {
                appFragment = NSLocalizedString("一个或多个应用", comment: "")
            }
            
            let failureReason = String(format: NSLocalizedString("软件源「%@」中存在 %@（涉及 %@）。", comment: ""), self.$source.name, versionFragment, appFragment)
            return failureReason
            
        case .blocked:
            let failureReason = String(format: NSLocalizedString("出于安全考虑，软件源「%@」已被 SideStore 拦截屏蔽。", comment: ""), self.$source.name)
            return failureReason
            
        case .changedID:
            let failureReason = String(format: NSLocalizedString("软件源「%@」的唯一标识符已发生变更。", comment: ""), self.$source.name)
            return failureReason
            
        case .duplicate:
            let baseMessage = String(format: NSLocalizedString("已存在标识符同为「%@」的软件源", comment: ""), self.$source.identifier)
            guard let existingSourceName = self.$existingSource.name else { return baseMessage + "." }
            
            let failureReason = baseMessage + " (“\(existingSourceName)”)."
            return failureReason
            
        case .missingPermissionUsageDescription:
            let appName = self.$app.name ?? String(format: NSLocalizedString("软件源「%@」中的某个应用", comment: ""), self.$source.name)
            guard let permission else {
                return String(format: NSLocalizedString("%@ 声明的某项权限缺少用途说明。", comment: ""), appName)
            }
            
            let permissionType = permission.type.localizedName ?? NSLocalizedString("权限", comment: "")
            let failureReason = String(format: NSLocalizedString("%@「%@」（所属应用：%@）缺少用途说明。", comment: ""), permissionType.lowercased(), permission.rawValue, appName)
            return failureReason
            
        case .missingScreenshotSize:
            let appName = self.$app.name ?? String(format: NSLocalizedString("软件源「%@」中的某个应用", comment: ""), self.$source.name)
            let baseMessage = String(format: NSLocalizedString("%@ 的 iPad 预览截图未标注尺寸参数", comment: ""), appName)
            guard let screenshotURL else { return baseMessage + "." }
            
            let failureReason = baseMessage + ": \(screenshotURL.absoluteString)"
            return failureReason
            
        case .marketplaceNotSupported:
            let failureReason = String(format: NSLocalizedString("软件源「%@」包含公正分发应用，当前版本的 SideStore 暂不支持。", comment: ""), self.$source.name)
            return failureReason
            
        case .marketplaceRequired:
            let failureReason = String(format: NSLocalizedString("软件源「%@」中存在缺少 marketplaceID 的应用，当前版本不支持。", comment: ""), self.$source.name)
            return failureReason
        }
    }
    
    var recoverySuggestion: String? {
        switch self.code
        {
        case .blocked:
            if self.existingSource != nil
            {
                // Source already added, so tell them to remove it + any installed apps.
                let baseMessage = NSLocalizedString("为保障设备安全，请移除该软件源并卸载", comment: "")
                
                if let blockedAppNames = self.blockedAppNames
                {
                    let recoverySuggestion = baseMessage + " " + NSLocalizedString("以下受影响应用：", comment: "") + "\n\n" + blockedAppNames.joined(separator: "\n")
                    return recoverySuggestion
                }
                else
                {
                    let recoverySuggestion = baseMessage + " " + NSLocalizedString("从该源下载的全部应用。", comment: "")
                    return recoverySuggestion
                }
            }
            else
            {
                // Source is not already added, so no need to tell users to remove it.
                // Instead, we just list all affected apps (if provided).
                guard let blockedAppNames else { return nil }
                
                let recoverySuggestion = NSLocalizedString("以下应用已被标记存在风险：", comment: "") + "\n\n" + blockedAppNames.joined(separator: "\n")
                return recoverySuggestion
            }
            
        case .changedID: return NSLocalizedString("软件源添加后不可更改自身标识符，该源无法继续自动更新，请移除后重新添加。", comment: "")
        case .duplicate:
            let recoverySuggestion = NSLocalizedString("请先移除已存在的同名标识符软件源，然后再重新添加此源。", comment: "")
            return recoverySuggestion
            
        case .marketplaceRequired:
            let failureReason = String(format: NSLocalizedString("此模式下仅可安装经 Apple 公正的市场应用。", comment: ""), self.$source.name)
            return failureReason
            
        default: return nil
        }
    }
}

private extension SourceError
{
    var blockedAppNames: [String]? {
        let blockedAppNames: [String]?
        
        if let existingSource
        {
            // Blocked apps = all installed apps from this source.
            blockedAppNames = self.$existingSource.perform { _ in
                let storeApps = existingSource.apps.lazy.filter { $0.installedApp != nil }
                guard !storeApps.isEmpty else { return nil }
                
                let appNames = storeApps.map { "\($0.name) (\($0.bundleIdentifier))" }
                return Array(appNames)
            }
        }
        else if let bundleIDs
        {
            // Blocked apps = explicitly listed bundleIDs in blocked source JSON entry.
            blockedAppNames = self.$source.perform { source in
                bundleIDs.compactMap { (bundleID) in
                    guard let storeApp = source._apps.lazy.compactMap({ $0 as? StoreApp }).first(where: { $0.bundleIdentifier == bundleID }) else { return nil }
                    return "\(storeApp.name) (\(storeApp.bundleIdentifier))"
                }
            }
        }
        else
        {
            blockedAppNames = nil
        }

        let sortedNames = blockedAppNames?.sorted { $0.localizedCompare($1) == .orderedAscending }
        return sortedNames
    }
}
