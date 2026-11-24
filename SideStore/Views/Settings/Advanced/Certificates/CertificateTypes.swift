//
//  CertificateTypes.swift
//  SideStore
//
//  Created by Magesh K on 2026-07-03.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SideSign

enum SortOption: String, CaseIterable, Identifiable {
    case creationDate = "创建时间"
    case expiryDate   = "到期时间"
    case name         = "名称"
    case keys         = "密钥状态"
    case type         = "证书类型"
    var id: String { rawValue }
}

enum GroupOption: String, CaseIterable, Identifiable {
    case none         = "不分组"
    case creationDate = "创建时间"
    case expiryDate   = "到期时间"
    case name         = "名称"
    case keys         = "密钥状态"
    case type         = "证书类型"
    var id: String { rawValue }
}

enum FileImportMode {
    case certificate
    case privateKey
}

struct KeyTextImportItem: Identifiable {
    let id: String
    let cert: ALTX509Certificate
}

struct GroupedCertificates: Identifiable {
    var id: String { name }
    let name: String
    let certificates: [ALTX509Certificate]
}
