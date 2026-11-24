#!/usr/bin/env python3
"""Patch LiveContainer source tree with:
1. Auto-Convert New Apps to Shared App (default ON, persisted in LCUtils.appGroupUserDefault)
2. One-click "Convert All Private Apps to Shared" action in Settings -> Multiple LiveContainers
3. Shared atomic conversion helper LCAppModel.convertToSharedApp(sharedModel:) protecting built-in SideStore
4. 100% Simplified Chinese (zh-Hans) localization coverage in Resources/Localizable.xcstrings
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def patch_file(path: Path, replacements: list[tuple[str, str]]) -> None:
    raw = path.read_text(encoding="utf-8")
    newline = "\r\n" if "\r\n" in raw else "\n"
    text = raw.replace("\r\n", "\n")

    for idx, (target, replacement) in enumerate(replacements, 1):
        count = text.count(target)
        if count != 1:
            raise RuntimeError(
                f"[{path}] replacement #{idx} expected 1 occurrence, found {count}.\n"
                f"Target snippet:\n{target[:240]}"
            )
        text = text.replace(target, replacement, 1)

    path.write_text(text.replace("\n", newline), encoding="utf-8")
    print(f"Patched: {path}")


def patch_utils_extensions(lc_root: Path) -> None:
    path = lc_root / "LiveContainerSwiftUI/Utilities/LCUtilsExtensions.swift"
    target = """extension LCUtils {
    public static let appGroupUserDefault = UserDefaults.init(suiteName: LCSharedUtils.appGroupID()) ?? UserDefaults.standard"""

    replacement = """extension LCUtils {
    public static let appGroupUserDefault = UserDefaults.init(suiteName: LCSharedUtils.appGroupID()) ?? UserDefaults.standard
    public static let autoConvertToSharedAppKey = "LCAutoConvertToSharedApp"

    public static var isAutoConvertToSharedAppEnabled: Bool {
        if appGroupUserDefault.object(forKey: autoConvertToSharedAppKey) == nil {
            return true
        }
        return appGroupUserDefault.bool(forKey: autoConvertToSharedAppKey)
    }

    public static var canUseSharedApps: Bool {
        return (LCUtils.isAppGroupAltStoreLike() || LCUtils.store() == .ADP)
            && LCPath.lcGroupDocPath.standardizedFileURL != LCPath.docPath.standardizedFileURL
    }"""

    patch_file(path, [(target, replacement)])


def patch_app_model(lc_root: Path) -> None:
    path = lc_root / "LiveContainerSwiftUI/Models/LCAppModel.swift"
    target = """    static func copy(fromApp: LCAppModel, toAppInfo: LCAppInfo) {"""

    replacement = """    var isBuiltInSideStore: Bool {
        if appInfo is BuiltInSideStoreAppInfo {
            return true
        }
        if appInfo.relativeBundlePath == "builtinSideStore" {
            return true
        }
        if let bundlePath = appInfo.bundlePath() {
            let standardizedBundle = URL(fileURLWithPath: bundlePath).standardizedFileURL.path
            let standardizedMain = Bundle.main.bundleURL.standardizedFileURL.path
            if standardizedBundle.hasPrefix(standardizedMain) {
                return true
            }
        }
        return false
    }

    @MainActor
    func convertToSharedApp(sharedModel: SharedModel) throws {
        guard !isBuiltInSideStore else {
            throw "lc.settings.multiLC.cannotConvertBuiltinSideStore".loc
        }
        guard !uiIsShared && !appInfo.isShared else {
            return
        }
        guard LCUtils.canUseSharedApps else {
            throw "lc.settings.multiLC.sharedAppUnavailable".loc
        }
        guard !isAppRunning else {
            throw "lc.container.inUse".loc
        }
        guard let bundlePath = appInfo.bundlePath(),
              let relativeBundlePath = appInfo.relativeBundlePath,
              !relativeBundlePath.isEmpty else {
            throw "lc.appList.appInfoInitError".loc
        }

        for container in appInfo.containers {
            if let runningLC = LCSharedUtils.getContainerUsingLCScheme(withFolderName: container.folderName) {
                throw String.localizedStringWithFormat("lc.appSettings.appOpenInOtherLc %@ %@".loc, runningLC, runningLC)
            }
        }

        try LCPath.ensureAppGroupPaths()

        let destBundleURL = LCPath.lcGroupBundlePath.appendingPathComponent(relativeBundlePath)
        var moves: [(URL, URL)] = []
        moves.append((
            URL(fileURLWithPath: bundlePath),
            destBundleURL
        ))
        for container in uiContainers {
            if container.storageBookMark != nil {
                continue
            }
            moves.append((
                LCPath.dataPath.appendingPathComponent(container.folderName),
                LCPath.lcGroupDataPath.appendingPathComponent(container.folderName)
            ))
        }
        if let tweakFolder = appInfo.tweakFolder, tweakFolder.count > 0 {
            moves.append((
                LCPath.tweakPath.appendingPathComponent(tweakFolder),
                LCPath.lcGroupTweakPath.appendingPathComponent(tweakFolder)
            ))
        }

        try LCUtils.moveFilesAtomicallyAfterPreflight(moves)

        for container in uiContainers {
            if container.storageBookMark != nil {
                continue
            }
            sharedModel.appDataFolderNames.removeAll(where: { $0 == container.folderName })
            container.isShared = true
        }

        if let tweakFolder = appInfo.tweakFolder, tweakFolder.count > 0 {
            sharedModel.tweakFolderNames.removeAll(where: { $0 == tweakFolder })
        }

        appInfo.setBundlePath(destBundleURL.path)
        appInfo.isShared = true
        uiIsShared = true
    }

    static func copy(fromApp: LCAppModel, toAppInfo: LCAppInfo) {"""

    patch_file(path, [(target, replacement)])


def patch_app_list_view(lc_root: Path) -> None:
    path = lc_root / "LiveContainerSwiftUI/Views/AppList/LCAppListView.swift"
    target = """        DispatchQueue.main.async {
            if let appToReplace {
                let newAppModel = LCAppModel(appInfo: finalNewApp, delegate: self)
                
                if appToReplace.uiIsHidden {
                    sharedModel.hiddenApps.removeAll { $0 == appToReplace }
                    sharedModel.hiddenApps.append(newAppModel)
                } else {
                    sharedModel.apps.removeAll { $0 == appToReplace }
                    sharedModel.apps.append(newAppModel)
                }

            } else {
                let newAppModel = LCAppModel(appInfo: finalNewApp, delegate: self)
                sharedModel.apps.append(newAppModel)
                
                // add url schemes
                if let urlSchemes = finalNewApp.urlSchemes(), urlSchemes.count > 0 {
                    UserDefaults.lcShared().mutableArrayValue(forKey: "LCGuestURLSchemes")
                        .addObjects(from: urlSchemes as! [Any])
                }
            }

            self.installprogressVisible = false
        }"""

    replacement = """        await MainActor.run {
            if let appToReplace {
                let newAppModel = LCAppModel(appInfo: finalNewApp, delegate: self)
                
                if appToReplace.uiIsHidden {
                    sharedModel.hiddenApps.removeAll { $0 == appToReplace }
                    sharedModel.hiddenApps.append(newAppModel)
                } else {
                    sharedModel.apps.removeAll { $0 == appToReplace }
                    sharedModel.apps.append(newAppModel)
                }

            } else {
                let newAppModel = LCAppModel(appInfo: finalNewApp, delegate: self)
                if sharedModel.multiLCStatus != 2,
                   LCUtils.isAutoConvertToSharedAppEnabled,
                   LCUtils.canUseSharedApps,
                   !newAppModel.isBuiltInSideStore,
                   !newAppModel.uiIsShared {
                    do {
                        try newAppModel.convertToSharedApp(sharedModel: sharedModel)
                    } catch {
                        NSLog("[LC] Auto-convert to shared app failed for \\(finalNewApp.relativeBundlePath ?? "unknown"), keeping as private app: \\(error.localizedDescription)")
                    }
                }
                sharedModel.apps.append(newAppModel)
                
                // add url schemes
                if let urlSchemes = finalNewApp.urlSchemes(), urlSchemes.count > 0 {
                    UserDefaults.lcShared().mutableArrayValue(forKey: "LCGuestURLSchemes")
                        .addObjects(from: urlSchemes as! [Any])
                }
            }

            self.installprogressVisible = false
        }"""

    patch_file(path, [(target, replacement)])


def patch_app_settings_view(lc_root: Path) -> None:
    path = lc_root / "LiveContainerSwiftUI/Views/AppList/AppSettings/LCAppSettingsView.swift"
    target = """        do {
            try LCPath.ensureAppGroupPaths()

            var moves: [(URL, URL)] = [];
            moves.append((
                URL(fileURLWithPath: appInfo.bundlePath()),
                LCPath.lcGroupBundlePath.appendingPathComponent(appInfo.relativeBundlePath)
            ))
            for container in model.uiContainers {
                if container.storageBookMark != nil {
                    continue
                }
                
                moves.append((
                    LCPath.dataPath.appendingPathComponent(container.folderName),
                    LCPath.lcGroupDataPath.appendingPathComponent(container.folderName)
                ))
            }
            if let tweakFolder = appInfo.tweakFolder, tweakFolder.count > 0 {
                moves.append((
                    LCPath.tweakPath.appendingPathComponent(tweakFolder),
                    LCPath.lcGroupTweakPath.appendingPathComponent(tweakFolder)
                ))
            }
            
            try LCUtils.moveFilesAtomicallyAfterPreflight(moves)
            
            for container in model.uiContainers {
                if container.storageBookMark != nil {
                    continue
                }
                sharedModel.appDataFolderNames.removeAll(where: { s in
                    return s == container.folderName
                })
                container.isShared = true
            }
            
            if let tweakFolder = appInfo.tweakFolder, tweakFolder.count > 0 {
                sharedModel.tweakFolderNames.removeAll(where: { s in
                    return s == tweakFolder
                })
            }
            
            appInfo.setBundlePath(LCPath.lcGroupBundlePath.appendingPathComponent(appInfo.relativeBundlePath).path)
            appInfo.isShared = true
            model.uiIsShared = true
        } catch {
            errorInfo = error.localizedDescription
            errorShow = true
        }"""

    replacement = """        do {
            try await MainActor.run {
                try model.convertToSharedApp(sharedModel: sharedModel)
            }
        } catch {
            errorInfo = error.localizedDescription
            errorShow = true
        }"""

    patch_file(path, [(target, replacement)])


def patch_settings_view(lc_root: Path) -> None:
    path = lc_root / "LiveContainerSwiftUI/Views/Settings/LCSettingsView.swift"
    target_storage = """    @AppStorage("LCDontSignApp", store: LCUtils.appGroupUserDefault) var dontSignApp = false"""
    replacement_storage = """    @AppStorage("LCDontSignApp", store: LCUtils.appGroupUserDefault) var dontSignApp = false
    @AppStorage(LCUtils.autoConvertToSharedAppKey, store: LCUtils.appGroupUserDefault) var autoConvertToSharedApp = true"""

    target_section = """                    } footer: {
                        Text("lc.settings.multiLCDesc".loc)
                    }
                }"""

    replacement_section = """                    } footer: {
                        Text("lc.settings.multiLCDesc".loc)
                    }
                }
                if sharedModel.multiLCStatus != 2 && LCUtils.canUseSharedApps {
                    Section {
                        Toggle(isOn: $autoConvertToSharedApp) {
                            Text("lc.settings.autoConvertToSharedApp".loc)
                        }
                    } footer: {
                        Text("lc.settings.autoConvertToSharedAppDesc".loc)
                    }
                }"""

    patch_file(
        path,
        [
            (target_storage, replacement_storage),
            (target_section, replacement_section),
        ],
    )


def patch_multi_lc_view(lc_root: Path) -> None:
    path = lc_root / "LiveContainerSwiftUI/Views/Settings/LCMultiLCManagementView.swift"

    target_props = """struct LCMultiLCManagementView : View, InstallAnotherLCButtonDelegate {
    @AppStorage("LCMultiAllowGameCategory") var useGameCategory = false
    @AppStorage("LCMultiAllowGameMode") var allowGameMode = false
    @State var errorShow = false
    @State var errorInfo = ""
    @State var successShow = false
    @State var successInfo = ""
    
    @State private var showShareSheet = false
    @State private var shareURL : URL? = nil
    @StateObject private var installLC2Alert = AlertHelper<Int>()
    @State private var launchPriorityItems: [LaunchPriorityLC] = []"""

    replacement_props = """struct LCMultiLCManagementView : View, InstallAnotherLCButtonDelegate {
    @AppStorage("LCMultiAllowGameCategory") var useGameCategory = false
    @AppStorage("LCMultiAllowGameMode") var allowGameMode = false
    @AppStorage(LCUtils.autoConvertToSharedAppKey, store: LCUtils.appGroupUserDefault) var autoConvertToSharedApp = true
    @State var errorShow = false
    @State var errorInfo = ""
    @State var successShow = false
    @State var successInfo = ""
    
    @State private var showShareSheet = false
    @State private var shareURL : URL? = nil
    @StateObject private var installLC2Alert = AlertHelper<Int>()
    @StateObject private var convertAllToSharedAlert = YesNoHelper()
    @State private var convertAllCandidateCount = 0
    @State private var isConvertingAllToShared = false
    @State private var launchPriorityItems: [LaunchPriorityLC] = []
    @EnvironmentObject private var sharedModel : SharedModel"""

    target_form_section = """            Section {
                InstallAnotherLCButton(lcName: "LiveContainer2", delegate: self)
                InstallAnotherLCButton(lcName: "LiveContainer3", delegate: self)
            } header: {
                Text("lc.settings.multiLCInstall".loc)
            }"""

    replacement_form_section = """            Section {
                InstallAnotherLCButton(lcName: "LiveContainer2", delegate: self)
                InstallAnotherLCButton(lcName: "LiveContainer3", delegate: self)
            } header: {
                Text("lc.settings.multiLCInstall".loc)
            }

            Section {
                Toggle(isOn: $autoConvertToSharedApp) {
                    Text("lc.settings.autoConvertToSharedApp".loc)
                }
                Button {
                    Task { await convertAllPrivateAppsToShared() }
                } label: {
                    HStack {
                        Text("lc.settings.multiLC.convertAllPrivateToShared".loc)
                        Spacer()
                        if isConvertingAllToShared {
                            ProgressView()
                        }
                    }
                }
                .disabled(isConvertingAllToShared || sharedModel.multiLCStatus == 2)
            } header: {
                Text("lc.settings.multiLC.sharedApps".loc)
            } footer: {
                Text("lc.settings.autoConvertToSharedAppDesc".loc)
            }"""

    target_alerts = """        .navigationTitle("lc.settings.multiLC".loc)
        .navigationBarTitleDisplayMode(.inline)
    }"""

    replacement_alerts = """        .alert("lc.settings.multiLC.convertAllPrivateToShared".loc, isPresented: $convertAllToSharedAlert.show) {
            Button {
                convertAllToSharedAlert.close(result: true)
            } label: {
                Text("lc.common.move".loc)
            }
            Button("lc.common.cancel".loc, role: .cancel) {
                convertAllToSharedAlert.close(result: false)
            }
        } message: {
            Text(String.localizedStringWithFormat("lc.settings.multiLC.convertAllPrivateConfirm %lld".loc, Int64(convertAllCandidateCount)))
        }
        .alert("lc.common.error".loc, isPresented: $errorShow) {
            Button("lc.common.ok".loc, role: .cancel) {}
        } message: {
            Text(errorInfo)
        }
        .alert("lc.common.success".loc, isPresented: $successShow) {
            Button("lc.common.ok".loc, role: .cancel) {}
        } message: {
            Text(successInfo)
        }
        .navigationTitle("lc.settings.multiLC".loc)
        .navigationBarTitleDisplayMode(.inline)
    }"""

    target_end = """        } catch {
            errorInfo = error.localizedDescription
            errorShow = true
        }
    }
}"""

    replacement_end = """        } catch {
            errorInfo = error.localizedDescription
            errorShow = true
        }
    }

    private func privateAppCandidates() -> [LCAppModel] {
        var allApps = sharedModel.apps
        if sharedModel.isHiddenAppUnlocked {
            allApps.append(contentsOf: sharedModel.hiddenApps)
        }
        return allApps.filter { !$0.uiIsShared && !$0.appInfo.isShared && !$0.isBuiltInSideStore }
    }

    func convertAllPrivateAppsToShared() async {
        guard !isConvertingAllToShared else {
            return
        }
        guard sharedModel.multiLCStatus != 2 else {
            errorInfo = "lc.appList.manageInPrimaryTip".loc
            errorShow = true
            return
        }
        guard LCUtils.canUseSharedApps else {
            errorInfo = "lc.settings.multiLC.sharedAppUnavailable".loc
            errorShow = true
            return
        }

        let initialCandidates = privateAppCandidates()
        guard !initialCandidates.isEmpty else {
            successInfo = "lc.settings.multiLC.convertAllPrivateResultNone".loc
            successShow = true
            return
        }

        convertAllCandidateCount = initialCandidates.count
        guard let confirmed = await convertAllToSharedAlert.open(), confirmed else {
            return
        }

        isConvertingAllToShared = true
        defer {
            isConvertingAllToShared = false
        }

        let candidates = privateAppCandidates()
        var convertedCount = 0
        var skippedCount = 0
        var skippedReasons: [String] = []

        for app in candidates {
            do {
                try await MainActor.run {
                    try app.convertToSharedApp(sharedModel: sharedModel)
                }
                convertedCount += 1
            } catch {
                skippedCount += 1
                skippedReasons.append("\\(app.displayName): \\(error.localizedDescription)")
                NSLog("[LC] Batch convert to shared failed for \\(app.appInfo.relativeBundlePath ?? app.displayName): \\(error.localizedDescription)")
            }
        }

        var message = String.localizedStringWithFormat(
            "lc.settings.multiLC.convertAllPrivateResult %lld %lld".loc,
            Int64(convertedCount),
            Int64(skippedCount)
        )
        if !skippedReasons.isEmpty {
            let preview = skippedReasons.prefix(3).joined(separator: "\\n")
            message += "\\n\\n\\(preview)"
        }
        successInfo = message
        successShow = true
    }
}"""

    patch_file(
        path,
        [
            (target_props, replacement_props),
            (target_form_section, replacement_form_section),
            (target_alerts, replacement_alerts),
            (target_end, replacement_end),
        ],
    )


def patch_xcstrings(lc_root: Path) -> None:
    path = lc_root / "Resources/Localizable.xcstrings"
    data = json.loads(path.read_text(encoding="utf-8"))
    strings = data["strings"]

    # 1. Fill upstream keys missing zh-Hans
    existing_zh_additions = {
        "lc.appSettings.classicModeDesc": "（实验性）引导系统以合适分辨率显示应用。在 iPadOS 上，如果应用不原生支持 iPad，将以 iPhone 模式显示。",
        "lc.appSettings.selected32BitEmulator": "32 位模拟器",
        "lc.settings.selected32BitEmulator": "默认 32 位模拟器",
    }
    for key, zh_val in existing_zh_additions.items():
        entry = strings.setdefault(key, {"extractionState": "manual", "localizations": {}})
        locs = entry.setdefault("localizations", {})
        if "zh-Hans" not in locs:
            locs["zh-Hans"] = {"stringUnit": {"state": "translated", "value": zh_val}}

    # 2. Add new auto-share & batch-share keys (en + zh-Hans)
    new_entries = {
        "lc.settings.autoConvertToSharedApp": (
            "Auto-Convert New Apps to Shared",
            "新装 App 默认转为共享 App",
        ),
        "lc.settings.autoConvertToSharedAppDesc": (
            "Automatically convert newly installed IPAs to Shared Apps so they can be used directly across multiple LiveContainers and multitasking.",
            "安装新 IPA 后自动转为共享 App，免手动逐个切换，供多 LiveContainer 与多任务直接使用",
        ),
        "lc.settings.multiLC.sharedApps": (
            "Shared Apps",
            "共享 App",
        ),
        "lc.settings.multiLC.convertAllPrivateToShared": (
            "Convert All Private Apps to Shared",
            "将现有私有 App 全部转为共享 App",
        ),
        "lc.settings.multiLC.convertAllPrivateConfirm %lld": (
            "Convert %lld private app(s) to Shared Apps for multiple LiveContainers and multitasking? Running apps will be skipped automatically.",
            "即将把现有的 %lld 个私有 App 全部转为共享 App，供多 LiveContainer 与多任务直接使用。运行中的 App 将自动跳过。",
        ),
        "lc.settings.multiLC.convertAllPrivateResult %lld %lld": (
            "Converted %lld app(s) to Shared App, skipped %lld.",
            "已转换 %lld 个为共享 App，跳过 %lld 个。",
        ),
        "lc.settings.multiLC.convertAllPrivateResultNone": (
            "No private apps need to be converted. All apps are already Shared Apps.",
            "当前没有需要转换的私有 App，所有 App 均已为共享 App。",
        ),
        "lc.settings.multiLC.sharedAppUnavailable": (
            "App Group is unavailable. Please install LiveContainer via SideStore, AltStore, or a certificate with App Group enabled.",
            "当前 App Group 不可用，请确认已通过 SideStore、AltStore 或开启 App Group 的证书安装 LiveContainer。",
        ),
        "lc.settings.multiLC.cannotConvertBuiltinSideStore": (
            "Built-in SideStore cannot be converted to a Shared App.",
            "内置 SideStore 不可转换为共享 App。",
        ),
    }

    for key, (en_val, zh_val) in new_entries.items():
        strings[key] = {
            "extractionState": "manual",
            "localizations": {
                "en": {"stringUnit": {"state": "translated", "value": en_val}},
                "zh-Hans": {"stringUnit": {"state": "translated", "value": zh_val}},
            },
        }

    missing_zh = [
        k for k, v in strings.items()
        if "en" in v.get("localizations", {}) and "zh-Hans" not in v.get("localizations", {})
    ]
    if missing_zh:
        raise RuntimeError(f"Localizable.xcstrings still missing zh-Hans for keys: {missing_zh}")

    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2, sort_keys=False) + "\n",
        encoding="utf-8",
    )
    print(f"Patched: {path} (total keys={len(strings)}, missing zh-Hans=0)")


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <LiveContainer-repo-dir>", file=sys.stderr)
        return 2

    lc_root = Path(sys.argv[1]).resolve()
    if not (lc_root / "LiveContainer.xcodeproj").is_dir():
        print(f"ERROR: Not a LiveContainer repo: {lc_root}", file=sys.stderr)
        return 1

    patch_utils_extensions(lc_root)
    patch_app_model(lc_root)
    patch_app_list_view(lc_root)
    patch_app_settings_view(lc_root)
    patch_settings_view(lc_root)
    patch_multi_lc_view(lc_root)
    patch_xcstrings(lc_root)
    print("OK: All LiveContainer source & localization patches applied cleanly.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
