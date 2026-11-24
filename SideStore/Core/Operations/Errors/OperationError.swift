//
//  OperationError.swift
//  SideStore
//
//  Created by Magesh K on 3/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation

public enum OperationError: LocalizedError, CustomNSError, Sendable, Equatable {
    case noInstalledApps
    case noSources
    case notAuthenticated
    case timedOut
    case unableToConnectSideJIT
    case unableToRespondSideJITDevice
    case unknownResult

    case cacheClearError(errors: [String])
    case certificateExpired(appName: String)
    case certificateRevoked(appName: String)
    case customCertificateExpired(appName: String, activeTeam: String)
    case customCertificateRevoked(appName: String, activeTeam: String)
    case forbidden(failureReason: String, file: String = #fileID, line: UInt = #line)
    case invalidApp(reason: String)
    case invalidPairingFile(reason: String)
    case invalidParameters(String)
    case invalidResponse(reason: String)
    case invalidVPN(reason: String)
    case minimuxerNotStarted(reason: String)
    case missingAppBundle(reason: String)
    case missingAppGroup(name: String)
    case missingInfoPlist(reason: String)
    case missingProvisioningProfile(reason: String)
    case missingUpdate(appName: String)
    case noConnection(reason: String)
    case noDevice(reason: String)
    case noVPN(reason: String)
    case notReachable(reason: String)
    case openAppFailed(name: String)
    case pairingNotComplete(reason: String)
    case pledgeInactive(appName: String)
    case SideJITIssue(error: String)
    case unknownUDID(reason: String)

    public static var cancelled: CancellationError { CancellationError() }

    public var rawDescription: String {
        switch self {
        case .noInstalledApps:
            return "当前没有需要刷新的已激活侧载应用。"
        case .noSources:
            return "当前尚未添加任何软件源。"
        case .notAuthenticated:
            return "你尚未登录 Apple ID，请先前往「设置」登录。"
        case .timedOut:
            return "操作超时，请检查网络连接与本地 VPN 状态后重试。"
        case .unableToConnectSideJIT:
            return "无法连接到 SideJITServer。请确认手机与电脑处于同一局域网 Wi-Fi，且电脑防火墙已放行对应端口。"
        case .unableToRespondSideJITDevice:
            return "SideJITServer 无法连接你的设备。请先在电脑终端运行 'SideJITServer -y' 完成配对，或在「设置 -> SideJITServer」刷新设备缓存。"
        case .unknownResult:
            return "操作返回了未知结果。"

        case .cacheClearError(let errors):
            return "清理缓存时发生错误：\(errors.joined(separator: "\n"))"
        case .certificateExpired(let appName):
            return "用于签名安装「\(appName)」的开发证书已过期，请对该应用执行「重签名」或重新安装。"
        case .certificateRevoked(let appName):
            return "用于签名安装「\(appName)」的开发证书已在 Apple 开发者中心被吊销，请重新签名或重装该应用。"
        case .customCertificateExpired(_, let activeTeam):
            return "当前选用的自定义/第三方签名证书（团队：\(activeTeam)）已过期。\n\n若无需使用自定义证书，请前往「设置 -> 签名证书管理」停用或切换证书。"
        case .customCertificateRevoked(_, let activeTeam):
            return "当前选用的自定义/第三方签名证书（团队：\(activeTeam)）已被吊销。\n\n若无需使用自定义证书，请前往「设置 -> 签名证书管理」停用或更换证书。"
        case .forbidden(let reason, _, _):
            return reason
        case .invalidApp(let reason):
            return "安装包格式无效：\(reason)"
        case .invalidPairingFile(let reason):
            return "当前配对文件已失效或不可用（原因：\(reason)）。\n\n请前往「设置 -> 配对文件管理」重新导入有效的配对文件；若仍报错，请连接电脑使用 iloader 或 idevicepair 重新生成配对文件。"
        case .invalidParameters(let msg):
            return "参数无效：\n\(msg)"
        case .invalidResponse(let reason):
            return "服务器响应无效：\(reason)"
        case .invalidVPN(let reason):
            return "本地 VPN 隧道连接异常：\n\(reason)\n\n请确认已打开 LocalDevVPN 并处于已连接状态。"
        case .minimuxerNotStarted(let reason):
            return "Minimuxer 本机通信服务尚未启动：\(reason)\n\n请先完成配对文件导入并连接 VPN 后再执行操作。"
        case .missingAppBundle(let reason):
            return "未找到应用包文件：\(reason)"
        case .missingAppGroup(let name):
            return "无法访问 SideStore 共享应用组容器「\(name)」。"
        case .missingInfoPlist(let reason):
            return "未找到应用的 Info.plist 配置文件：\(reason)"
        case .missingProvisioningProfile(let reason):
            return "未找到该应用的签名描述文件：\(reason)"
        case .missingUpdate(let appName):
            return "未找到「\(appName)」兼容当前系统的可用更新。"
        case .noConnection(let reason):
            return "网络连接异常：\n\(reason)\n\n请连接 Wi-Fi 网络后再试。"
        case .noDevice(let reason):
            return "SideStore 无法连通本机服务端点：\n\(reason)\n\n请检查 LocalDevVPN 是否已连接，或前往「设置 -> 连接配置」核对参数。"
        case .noVPN(let reason):
            return "本地 VPN 隧道连接异常：\n\(reason)\n\n请确认已打开 LocalDevVPN 并处于已连接状态。"
        case .notReachable(let reason):
            return reason.isEmpty ? "无法连通指定 IP 或设备端点，请检查 VPN 隧道状态。" : reason
        case .openAppFailed(let name):
            return "SideStore 启动「\(name)」的权限被系统拒绝。"
        case .pairingNotComplete(let reason):
            return "缺少配对文件：\(reason)\n\n未配置有效配对文件前 SideStore 无法连接本机安装服务。请先前往「设置 -> 配对文件管理」导入配对文件。"
        case .pledgeInactive(let appName):
            return "你的赞助订阅状态已失效，请续订后继续正常使用 \(appName)。"
        case .SideJITIssue(let error):
            return "调用 SideJIT 时出错：\(error)"
        case .unknownUDID(let reason):
            return "SideStore 无法识别当前设备的 UDID：\(reason)\n\n请连接电脑使用 iloader 或 idevicepair 重新生成并导入配对文件。"
        }
    }

    public var errorDescription: String? {
        return self.failureReason
    }

    public var failureReason: String? {
        return NSLocalizedString(self.rawDescription, comment: "")
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidPairingFile:
            return NSLocalizedString("请导入有效的 .mobiledevicepairing 配对文件。", comment: "")
        case .invalidVPN, .noVPN:
            return NSLocalizedString("请确保 LocalDevVPN 已开启并保持连接！", comment: "")
        case .noConnection:
            return NSLocalizedString("请先连接至 Wi-Fi 无线局域网或有线网络！", comment: "")
        default:
            return nil
        }
    }
}
