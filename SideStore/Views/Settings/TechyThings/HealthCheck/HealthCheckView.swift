//
//  HealthCheckView.swift
//  SideStore
//
//  Created by Magesh K on 11/07/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import Minimuxer

struct HealthCheckView: View {
    @StateObject private var viewModel = HealthCheckViewModel()
    
    var body: some View {
        List {
            // Section 1: Connection Status Header
            Section {
                VStack(spacing: 12) {
                    if let result = viewModel.minimuxerReadyResult {
                        switch result {
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.green)
                            Text("SideStore 运行环境正常")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(viewModel.connectionMode == .localVPN
                                 ? "所有核心条件均已就绪，本地配对服务与 VPN 隧道连接正常。"
                                 : "所有核心条件均已就绪，配对服务与远程节点连接正常。"
                            )
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        case .failure(let err):
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.orange)
                            Text("需要处理")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(err.localizedDescription)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        ProgressView("正在检测运行环境状态…")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            
            // Section 2: Core Dependencies
            Section(header: Text("核心侧载环境检查")) {
                DependencyRow(
                    title: "无线网络连接",
                    subtitle: viewModel.networkSatisfied == nil ? "未知" : (viewModel.isWifiSatisfied ? "Wi-Fi 已连接" : "未连接 Wi-Fi"),
                    isSatisfied: viewModel.networkSatisfied
                )
                
                if viewModel.connectionMode == .localVPN {
                    DependencyRow(
                        title: "本地 VPN 隧道 (utun)",
                        subtitle: viewModel.vpnSatisfied == nil ? "未知" : (viewModel.isUTunAvailable ? "已连接" : "未连接"),
                        isSatisfied: viewModel.vpnSatisfied
                    )
                    
                    if !viewModel.isRPPairing {
                        if #available(iOS 26.4, *) {
                            DependencyRow(
                                title: "IPSec/IKEv2 隧道",
                                subtitle: viewModel.ipsecSatisfied == nil ? "未知" : (viewModel.isIKEv2IPSecAvailable ? "已连接" : "未连接"),
                                isSatisfied: viewModel.ipsecSatisfied
                            )
                        }
                    }
                }
                
                DependencyRow(
                    title: "本机服务连通性 (Ping)",
                    subtitle: viewModel.pingSatisfied == nil ? "未知" : (viewModel.isPingSuccessful ? "可达" : "不可达"),
                    isSatisfied: viewModel.pingSatisfied
                )
                
                DependencyRow(
                    title: "设备配对文件",
                    subtitle: viewModel.isPairingFileVerified ? "已验证" : (viewModel.isPairingFileLoaded ? "已加载（但连接未通）" : "未验证或未导入"),
                    isSatisfied: viewModel.pairingSatisfied
                )
            }
            
            // Section 3: JIT Dependencies
            Section(header: Text("JIT 即时编译环境")) {
                DependencyRow(
                    title: "开发者磁盘映像 (DDI)",
                    subtitle: viewModel.isDDIMounted ? "已挂载" : "未挂载（暂无法使用 JIT）",
                    isSatisfied: viewModel.ddiSatisfied,
                    isOptional: true
                )
            }
            
            // Section 4: Connection Configuration
            Section(header: Text("当前连接参数")) {
                HStack {
                    Text("连接模式")
                    Spacer()
                    Text(viewModel.connectionMode == .localVPN ? "本地回环 VPN" : "远程服务器")
                        .foregroundColor(.secondary)
                }
                
                if viewModel.connectionMode == .localVPN {
                    ConfigRow(label: "隧道接口 IP", value: viewModel.tunnelIfaceIp)
                    ConfigRow(label: "隧道对端 IP", value: viewModel.tunnelPeerIp)
                    ConfigRow(label: "手动覆盖对端 IP", value: viewModel.overrideTunnelPeerIp.isEmpty ? nil : viewModel.overrideTunnelPeerIp)
                    HStack {
                        Text("手动覆盖状态")
                        Spacer()
                        Text(viewModel.overrideTunnelPeerEffective ? "已激活" : "未激活")
                            .foregroundColor(viewModel.overrideTunnelPeerEffective ? .green : .secondary)
                    }
                    HStack {
                        Text("当前活跃协议")
                        Spacer()
                        Text(viewModel.activeProtocol)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ConfigRow(label: "远程节点 IP", value: viewModel.remoteServerIp.isEmpty ? nil : viewModel.remoteServerIp)
                    HStack {
                        Text("当前活跃协议")
                        Spacer()
                        Text(viewModel.activeProtocol)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Section 4: All Active Interfaces
            Section(header: Text("当前活动网络接口")) {
                if viewModel.availableInterfaces.isEmpty {
                    Text("暂未扫描到活动网络接口。")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    let vpnInterfaces = viewModel.availableInterfaces.filter { $0.type.isVPN }
                    let localInterfaces = viewModel.availableInterfaces.filter { !$0.type.isVPN }
                    
                    if !vpnInterfaces.isEmpty {
                        ForEach(vpnInterfaces) { iface in
                            InterfaceRow(iface: iface)
                        }
                    }
                    
                    if !localInterfaces.isEmpty {
                        ForEach(localInterfaces) { iface in
                            InterfaceRow(iface: iface)
                        }
                    }
                }
            }
        }
        .navigationTitle("运行环境自检")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await viewModel.observeMetrics()
        }
    }
}

struct DependencyRow: View {
    let title: String
    let subtitle: String
    let isSatisfied: Bool?
    var isOptional: Bool = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let satisfied = isSatisfied {
                if satisfied {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                } else if isOptional {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                }
            } else {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            }
        }
    }
}

struct ConfigRow: View {
    let label: String
    let value: String?
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value ?? "N/A")
                .foregroundColor(.secondary)
        }
    }
}

struct InterfaceRow: View {
    let iface: LocalInterfaceInfo
    
    private var hasIPv4: Bool {
        !iface.subnet.isEmpty && !iface.ip.contains(":")
    }
    
    private var ipv4Host: String {
        hasIPv4 ? iface.ip : "N/A"
    }
    
    private var ipv4Mask: String {
        !iface.subnet.isEmpty ? iface.subnet : "N/A"
    }
    
    private var ipv6Address: String {
        if let v6 = iface.ipv6, !v6.isEmpty {
            return v6
        }
        if iface.ip.contains(":") {
            return iface.ip
        }
        return "N/A"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("网卡：")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 36, alignment: .leading)
                
                Text(iface.name)
                    .fontWeight(.semibold)
                
                Text(iface.type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(iface.type.isVPN ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                    .foregroundColor(iface.type.isVPN ? .blue : .primary)
                    .cornerRadius(4)
                
                Spacer()
            }
            .padding(.bottom, 2)
            
            HStack(alignment: .top, spacing: 8) {
                Text("IPv4:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 36, alignment: .leading)
                
                Text(ipv4Host)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(hasIPv4 ? .primary : .secondary)
                
                if hasIPv4 {
                    Text("(\(ipv4Mask))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(alignment: .top, spacing: 8) {
                Text("IPv6:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 36, alignment: .leading)
                
                Text(ipv6Address)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(ipv6Address != "N/A" ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}
