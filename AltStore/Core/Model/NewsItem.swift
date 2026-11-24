//
//  NewsItem.swift
//  AltStore
//
//  Created by Riley Testut on 8/29/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import CoreData

@objc(NewsItem)
public class NewsItem: BaseEntity, Decodable
{
    /* Properties */
    @NSManaged public var identifier: String
    @NSManaged public var date: Date
    
    @NSManaged public var title: String
    @NSManaged public var caption: String
    @NSManaged public var tintColor: UIColor
    @NSManaged public var sortIndex: Int32
    @NSManaged public var isSilent: Bool
    
    @NSManaged public var imageURL: URL?
    @NSManaged public var externalURL: URL?
    
    @NSManaged public var appID: String?
    @NSManaged public var sourceIdentifier: String?
    
    /* Relationships */
    @NSManaged public var storeApp: StoreApp?
    @NSManaged public var source: Source?
    
    private enum CodingKeys: String, CodingKey
    {
        case identifier
        case date
        case title
        case caption
        case tintColor
        case imageURL
        case externalURL = "url"
        case appID
        case notify
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
    
    public required init(from decoder: Decoder) throws
    {
        guard let context = decoder.managedObjectContext else { preconditionFailure("Decoder must have non-nil NSManagedObjectContext.") }
        
        super.init(entity: NewsItem.entity(), insertInto: context)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.date = try container.decode(Date.self, forKey: .date)
        
        self.title = try container.decode(String.self, forKey: .title)
        self.caption = try container.decode(String.self, forKey: .caption)
        
        if let tintColorHex = try container.decodeIfPresent(String.self, forKey: .tintColor)
        {
            guard let tintColor = UIColor(hexString: tintColorHex) else {
                throw DecodingError.dataCorruptedError(forKey: .tintColor, in: container, debugDescription: "Hex code is invalid.")
            }
            
            self.tintColor = tintColor
        }
        
        self.imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        self.externalURL = try container.decodeIfPresent(URL.self, forKey: .externalURL)
        
        // TODO: app specific news should be moved to appEntity (via refactoring)
        //       This can be done by: 1. having two newsItem schema, one for source and one for StoreApp
        //                            2. move this appID field into the newItem schema which is under StoreApp.
        self.appID = try container.decodeIfPresent(String.self, forKey: .appID)
        
        let notify = try container.decodeIfPresent(Bool.self, forKey: .notify) ?? false
        self.isSilent = !notify
    }
}

public extension NewsItem
{
    var globallyUniqueID: String? {
        guard let sourceIdentifier = self.sourceIdentifier else { return nil }
        
        let globallyUniqueID = self.identifier + "|" + sourceIdentifier
        return globallyUniqueID
    }
}

public extension NewsItem
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<NewsItem>
    {
        return NSFetchRequest<NewsItem>(entityName: "NewsItem")
    }
    
    class func sortedFetchRequest(for source: Source?) -> NSFetchRequest<NewsItem>
    {
        let fetchRequest = NewsItem.fetchRequest() as NSFetchRequest<NewsItem>
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \NewsItem.date, ascending: false),
                                        NSSortDescriptor(keyPath: \NewsItem.sortIndex, ascending: true),
                                        NSSortDescriptor(keyPath: \NewsItem.sourceIdentifier, ascending: true)]
        
        if let source
        {
            fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(NewsItem.source), source)
        }
        
        return fetchRequest
    }
}

// MARK: - SideStore-zh-CN Remote News Localization

public extension NewsItem
{
    var localizedTitle: String {
        SideStoreNewsLocalizer.localizedTitle(for: self)
    }

    var localizedCaption: String {
        SideStoreNewsLocalizer.localizedCaption(for: self)
    }
}

public enum SideStoreNewsLocalizer
{
    private struct Entry {
        let title: String
        let caption: String
    }

    // Known official SideStore & SideStore Team Picks remote news entries (by lowercased identifier)
    private static let entriesByIdentifier: [String: Entry] = [
        // https://sidestore.io/apps-v2.json/ (official default source)
        "welcome": Entry(
            title: "欢迎使用 SideStore！",
            caption: "点击查看使用文档了解更多信息"
        ),
        "caution": Entry(
            title: "使用须知",
            caption: "SideStore 目前为预览版软件，如遇异常欢迎反馈"
        ),
        "error24": Entry(
            title: "错误 0xe8008024 / 0xe8008018 说明",
            caption: "官方已知悉该问题，正在积极排查修复中"
        ),
        "update-064": Entry(
            title: "SideStore 0.6.4",
            caption: "⚠️ 新版本已发布，带来全新稳定性优化，点击查看详情！"
        ),

        // https://apps.sidestore.io (legacy official source)
        "update-062": Entry(
            title: "SideStore 0.6.2",
            caption: "新版本已发布，带来全新功能与稳定性优化！"
        ),
        "trustedsource": Entry(
            title: "新增更多官方推荐源！",
            caption: "现已将 PojavLauncher 引入 SideStore！"
        ),
        "support-ukraine": Entry(
            title: "人道主义援助倡议",
            caption: "了解如何向受冲突影响的人群提供支持与帮助。"
        ),

        // https://community-apps.sidestore.io/sidecommunity.json (SideStore Team Picks)
        "trusted-sources": Entry(
            title: "SideStore 可信软件源上线！",
            caption: "前往下方「浏览」标签页，即可访问经官方审核并持续维护的软件源。"
        ),
        "sideloading-is-here": Entry(
            title: "如何侧载任意应用！",
            caption: "在「我的应用」页面点击左上角「+」，即可直接从「文件」安装任意 iOS 应用。"
        ),
        "welcome-provenance-pojavlauncher": Entry(
            title: "新增更多可信软件源！",
            caption: "欢迎 Provenance 与 PojavLauncher 入驻软件源 🎉"
        ),
        "oldos-release": Entry(
            title: "OldOS 现已上架！",
            caption: "在一个应用里重温经典 iOS 4 怀旧体验！"
        ),
        "taurine-release": Entry(
            title: "Taurine 现已上架！",
            caption: "支持 iOS 14.0 - 14.3"
        ),
        "idos-altstore-now-available": Entry(
            title: "iDOS 现已上架",
            caption: "iDOS 模拟器现已开放下载，随时重温经典 DOS 游戏。"
        ),
        "play-download-now": Entry(
            title: "立即下载 Play! 模拟器",
            caption: "iOS 平台上出色的 PS2 游戏模拟器。"
        ),
        "scummvm-first-release-altstore": Entry(
            title: "体验 ScummVM！",
            caption: "指尖畅玩经典点击式冒险游戏。"
        ),
        "uncover-available-download": Entry(
            title: "unc0ver 现已发布！",
            caption: "功能强大的越狱工具，点击即可下载。"
        ),
        "uncover-v5-release": Entry(
            title: "unc0ver 5.0.0 正式发布！",
            caption: "功能强大的越狱工具，支持 iOS 11 - 13.5。"
        ),
        "itorrent-available-download": Entry(
            title: "iTorrent 现已上架",
            caption: "简洁高效的 iOS 磁力与种子下载客户端。"
        ),
        "inds-now-available": Entry(
            title: "iNDS 现已开放下载",
            caption: "经典 iOS 平台任天堂 DS 模拟器回归之作。"
        ),
        "countdown-now-avaliable": Entry(
            title: "Countdown 上架 SideStore",
            caption: "如果能提前知晓生命的倒计时，你会想知道吗？"
        ),
        "blurt-blog-2023-01-01": Entry(
            title: "blurt.blog 现已开放下载",
            caption: "Blurt.blog 社交客户端现已上架。"
        ),
        "3speak-tv-acela-download-2022-12-08": Entry(
            title: "3Speak.tv Acela 现已开放下载",
            caption: "3Speak.tv Acela 客户端现已上架。"
        ),

        // https://github.com/LiveContainer/LiveContainer/releases/download/1.0/apps_ss_lc.json (LiveContainer + SideStore source)
        "release-3.6.0": Entry(
            title: "LiveContainer 3.6.0 现已发布",
            caption: "LiveContainer 新版本已发布！"
        ),
        "release-3.6.1": Entry(
            title: "LiveContainer 3.6.1 现已发布",
            caption: "LiveContainer 新版本已发布！"
        )
    ]

    private static let exactTitleMap: [String: String] = [
        "welcome to sidestore!": "欢迎使用 SideStore！",
        "proceed with caution!": "使用须知",
        "error 0xe8008024 / 0xe8008018": "错误 0xe8008024 / 0xe8008018 说明",
        "added more sources!": "新增更多官方推荐源！",
        "more trusted sources!": "新增更多可信软件源！",
        "trusted sources within sidestore!": "SideStore 可信软件源上线！",
        "how to sideload any app!": "如何侧载任意应用！",
        "#standwithukraine": "人道主义援助倡议",
        "oldos now available!": "OldOS 现已上架！",
        "taurine now available!": "Taurine 现已上架！",
        "idos now available.": "iDOS 现已上架",
        "download play! now.": "立即下载 Play! 模拟器",
        "check out scummvm!": "体验 ScummVM！",
        "unc0ver out now!": "unc0ver 现已发布！",
        "unc0ver 5.0.0 out now!": "unc0ver 5.0.0 正式发布！",
        "itorrent now available": "iTorrent 现已上架",
        "inds available for download.": "iNDS 现已开放下载",
        "countdown comes to sidestore": "Countdown 上架 SideStore",
        "blurt.blog - download now - via altstore": "blurt.blog 现已开放下载",
        "3speak.tv acela - download now - via altstore": "3Speak.tv Acela 现已开放下载"
    ]

    private static let exactCaptionMap: [String: String] = [
        "check out the documentation for more info": "点击查看使用文档了解更多信息",
        "sidestore is currently pre-release software. expect bugs, and please report them": "SideStore 目前为预览版软件，如遇异常欢迎反馈",
        "we are aware of the issue and actively investigating it!": "官方已知悉该问题，正在积极排查修复中",
        "⚠️a new version has released with new stability improvements, tap for more info!": "⚠️ 新版本已发布，带来全新稳定性优化，点击查看详情！",
        "⚠️ a new version has released with new stability improvements, tap for more info!": "⚠️ 新版本已发布，带来全新稳定性优化，点击查看详情！",
        "a new version has released with new stability improvements, tap for more info!": "新版本已发布，带来全新稳定性优化，点击查看详情！",
        "a new version has released with new features and stability improvements!": "新版本已发布，带来全新功能与稳定性优化！",
        "introducing pojavlauncher to sidestore!": "现已将 PojavLauncher 引入 SideStore！",
        "find out how you can help support those impacted by the russian invasion.": "了解如何向受冲突影响的人群提供支持与帮助。",
        "simply go to the browse tab below to access app sources we vet and keep up to date.": "前往下方「浏览」标签页，即可访问经官方审核并持续维护的软件源。",
        "install any ios app directly from files by tapping the + in the my apps tab.": "在「我的应用」页面点击左上角「+」，即可直接从「文件」安装任意 iOS 应用。",
        "please welcome provenance and pojavlauncher to altstore 🎉": "欢迎 Provenance 与 PojavLauncher 入驻软件源 🎉",
        "update of livecontainer just got released!": "LiveContainer 新版本已发布！"
    ]

    public static func localizedTitle(for newsItem: NewsItem) -> String {
        localizedTitle(identifier: newsItem.identifier, title: newsItem.title)
    }

    public static func localizedCaption(for newsItem: NewsItem) -> String {
        localizedCaption(identifier: newsItem.identifier, title: newsItem.title, caption: newsItem.caption)
    }

    public static func localizedTitle(identifier: String, title: String) -> String {
        let normalizedID = normalize(identifier)
        if let entry = entriesByIdentifier[normalizedID] {
            // Preserve version number dynamically if identifier is reused for another SideStore version
            if normalizedID.hasPrefix("update-"), let versionTitle = formatSideStoreVersionTitle(title) {
                return versionTitle
            }
            return entry.title
        }

        let normalizedTitle = normalize(title)
        if let mapped = exactTitleMap[normalizedTitle] {
            return mapped
        }

        // Generic pattern: "SideStore X.Y.Z ..."
        if let versionTitle = formatSideStoreVersionTitle(title) {
            return versionTitle
        }

        // Generic pattern: "X.Y.Z - LiveContainer ..."
        if let lcVersionTitle = formatLiveContainerVersionTitle(title) {
            return lcVersionTitle
        }

        // Generic pattern: "Error 0x..."
        if normalizedTitle.hasPrefix("error 0x") {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let codePart = trimmed.dropFirst("Error ".count)
            return "错误 \(codePart) 说明"
        }

        // Keyword fallbacks
        if normalizedTitle.contains("welcome to sidestore") {
            return "欢迎使用 SideStore！"
        }
        if normalizedTitle.contains("proceed with caution") {
            return "使用须知"
        }

        return title
    }

    public static func localizedCaption(identifier: String, title: String, caption: String) -> String {
        let normalizedCaption = normalize(caption)
        if let mapped = exactCaptionMap[normalizedCaption] {
            return mapped
        }

        let normalizedID = normalize(identifier)
        if let entry = entriesByIdentifier[normalizedID] {
            return entry.caption
        }

        // Generic pattern: SideStore release notes / update captions
        if normalizedCaption.contains("new version has released") || normalizedCaption.contains("new version is out") {
            let hasWarning = caption.contains("⚠️")
            let prefix = hasWarning ? "⚠️ " : ""
            let tapHint = normalizedCaption.contains("tap for more info") || normalizedCaption.contains("tap to learn more") ? "，点击查看详情" : ""
            if normalizedCaption.contains("features") && normalizedCaption.contains("stability") {
                return "\(prefix)新版本已发布，带来全新功能与稳定性优化\(tapHint)！"
            } else if normalizedCaption.contains("stability") {
                return "\(prefix)新版本已发布，带来全新稳定性优化\(tapHint)！"
            } else if normalizedCaption.contains("bug") || normalizedCaption.contains("fix") {
                return "\(prefix)新版本已发布，修复了若干已知问题\(tapHint)！"
            } else {
                return "\(prefix)新版本已发布\(tapHint)！"
            }
        }

        // Keyword fallbacks for common official announcements
        if normalizedCaption.contains("check out the documentation") {
            return "点击查看使用文档了解更多信息"
        }
        if normalizedCaption.contains("pre-release software") {
            return "SideStore 目前为预览版软件，如遇异常欢迎反馈"
        }
        if normalizedCaption.contains("aware of the issue") && normalizedCaption.contains("investigating") {
            return "官方已知悉该问题，正在积极排查修复中"
        }

        _ = title
        return caption
    }

    private static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func formatSideStoreVersionTitle(_ title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^sidestore\s+v?(\d+\.\d+(?:\.\d+)?(?:-[A-Za-z0-9.\-]+)?)(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let versionRange = Range(match.range(at: 1), in: trimmed),
              let suffixRange = Range(match.range(at: 2), in: trimmed) else {
            return nil
        }

        let version = String(trimmed[versionRange])
        let suffix = String(trimmed[suffixRange]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if suffix.isEmpty {
            return "SideStore \(version)"
        }
        if suffix.contains("now available") || suffix.contains("out now") || suffix.contains("released") {
            return "SideStore \(version) 现已发布"
        }
        return "SideStore \(version)"
    }

    private static func formatLiveContainerVersionTitle(_ title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^v?(\d+\.\d+(?:\.\d+)?(?:-[A-Za-z0-9.\-]+)?)\s*-\s*livecontainer\b.*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let versionRange = Range(match.range(at: 1), in: trimmed) else {
            return nil
        }
        let version = String(trimmed[versionRange])
        return "LiveContainer \(version) 现已发布"
    }
}
