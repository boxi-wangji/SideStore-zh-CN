//
//  WidgetUpdateIntent.swift
//  AltStore
//
//  Created by Magesh K on 10/01/25.
//  Copyright © 2025 SideStore. All rights reserved.
//

import AppIntents

@available(iOS 17, *)
final class WidgetUpdateIntent: WidgetConfigurationIntent, @unchecked Sendable {
    public static let COMMON_WIDGET_ID = 1
    
    static var title: LocalizedStringResource { "Widget ID update Intent" }
    static var isDiscoverable: Bool { false }
    
    @Parameter(title: "ID", description: "指定用于区分多个小组件实例的数字编号", default: 1)
    var ID: Int?
}
