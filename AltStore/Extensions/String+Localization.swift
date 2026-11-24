//
//  String+Localization.swift
//  AltStore
//
//  Created by Magesh K on 8/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import UIKit

public extension String {
    init(formatted: String, comment: String? = nil, _ args: String...) {
        self.init(format: NSLocalizedString(formatted, comment: comment ?? ""), args)
    }
}

private let zhSystemStrings: [String: String] = [
    "OK": "好",
    "Cancel": "取消",
    "Done": "完成",
    "Continue": "继续",
    "Retry": "重试",
    "Delete": "删除",
    "Remove": "移除",
    "Save": "保存",
    "Close": "关闭",
    "Edit": "编辑",
    "Share": "分享",
    "Copy": "复制"
]

public func systemLocalizedString(_ string: String) -> String {
    if let zh = zhSystemStrings[string] {
        return zh
    }
    let bundle = Bundle(for: UIApplication.self)
    let localizedString = bundle.localizedString(forKey: string, value: "com.sidestore.SystemLocalizedStringNotFound", table: nil)
    if localizedString == "com.sidestore.SystemLocalizedStringNotFound" {
        return NSLocalizedString(string, comment: "")
    }
    return localizedString
}
