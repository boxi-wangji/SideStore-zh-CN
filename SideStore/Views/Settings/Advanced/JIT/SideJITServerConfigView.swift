//
//  SideJITServerConfigView.swift
//  SideStore
//
//  Created by Magesh K on 23/8/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI

enum SideJITConnectionStatus: Equatable {
    case disabled
    case ready(latencyMs: Int, address: String)
    case discovering
    case disconnected(reason: String)
    case checking
    
    var color: Color {
        switch self {
        case .disabled: return .secondary
        case .ready: return .green
        case .discovering, .checking: return .orange
        case .disconnected: return .red
        }
    }
    
    var title: String {
        switch self {
        case .disabled: return "未启用"
        case .ready(let latency, _): return "已就绪 (\(latency) ms)"
        case .discovering: return "正在通过 Bonjour 发现服务…"
        case .checking: return "正在测试连接…"
        case .disconnected: return "无法连接"
        }
    }
}

struct SideJITResponseLog: Identifiable {
    let id = UUID()
    let timestamp: Date
    let endpoint: String
    let httpMethod: String
    let statusCode: Int
    let latencyMs: Int
    let rawPayload: String
    
    var isSuccess: Bool {
        statusCode >= 200 && statusCode < 300
    }
    
    var prettyPayload: String {
        rawPayload.prettyPrintedJSON
    }
}

public extension String {
    var prettyPrintedJSON: String {
        guard let data = self.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return self
        }
        return prettyString
    }
}

enum SideJITDiagnosticAction: Equatable {
    case ping
    case refresh
    case version
}

struct SideJITServerConfigView: View {
    @State private var isServerEnabled: Bool = UserDefaults.standard.isSideJITServerEnabled
    @State private var customAddress: String = UserDefaults.standard.textInputSideJITServerurl ?? ""
    @State private var resolvedAddress: String = ""
    @State private var connectionStatus: SideJITConnectionStatus = UserDefaults.standard.isSideJITServerEnabled ? .checking : .disabled
    @State private var latestLog: SideJITResponseLog? = nil
    @State private var activeAction: SideJITDiagnosticAction? = nil
    @State private var showCopiedToast = false

    var body: some View {
        List {
            headerSection
            statusSection
            configurationSection
            diagnosticActionsSection
            if let log = latestLog {
                responseInspectorSection(log: log)
            }
            aboutSection
        }
        #if !os(tvOS)
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        #else
        .listStyle(.grouped)
        #endif
        .navigationTitle("SideJITServer")
        .overlay(
            Group {
                if showCopiedToast {
                    copiedToastView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            },
            alignment: .bottom
        )
        .onAppear {
            refreshServerState()
        }
    }
    
    private var headerSection: some View {
        Section {
            Toggle(isOn: $isServerEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("启用 SideJITServer 支持")
                            .font(.body.weight(.semibold))
                        Text("iOS 17 及以上系统无线开启 JIT 所需")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onChange(of: isServerEnabled) { newValue in
                UserDefaults.standard.isSideJITServerEnabled = newValue
                if newValue {
                    refreshServerState()
                } else {
                    connectionStatus = .disabled
                    resolvedAddress = ""
                }
            }
        }
    }
    
    private var statusSection: some View {
        Section(header: Text("连接状态")) {
            HStack {
                Text("状态")
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(connectionStatus.color)
                        .frame(width: 8, height: 8)
                    Text(connectionStatus.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("解析地址")
                    .layoutPriority(1)
                Spacer()
                Text(!isServerEnabled ? "已禁用" : (resolvedAddress.isEmpty ? "正在解析…" : resolvedAddress))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor((!isServerEnabled || resolvedAddress.isEmpty) ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .contextMenu {
                if !resolvedAddress.isEmpty {
                    SwiftUI.Button {
                        #if !os(tvOS)
                        UIPasteboard.general.string = resolvedAddress
                        showCopied()
                        #endif
                    } label: {
                        Label("复制地址", systemImage: "doc.on.doc")
                    }
                }
            }
            
            HStack {
                Text("寻址方式")
                Spacer()
                Text(customAddress.isEmpty ? "自动发现 (Bonjour mDNS)" : "手动指定地址")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var configurationSection: some View {
        Section(
            header: Text("服务器地址"),
            footer: Text("留空即可通过局域网 Bonjour 自动发现运行中的 SideJITServer。")
        ) {
            HStack {
                TextField(AppConstants.SideJIT.defaultServerURL, text: $customAddress)
                    .font(.system(size: 12.5, design: .monospaced))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                    .onChange(of: customAddress) { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        UserDefaults.standard.textInputSideJITServerurl = trimmed.isEmpty ? nil : trimmed
                        refreshServerState()
                    }
                
                if !customAddress.isEmpty {
                    SwiftUI.Button {
                        customAddress = ""
                        UserDefaults.standard.textInputSideJITServerurl = nil
                        refreshServerState()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var diagnosticActionsSection: some View {
        Section(header: Text("连通性测试与工具")) {
            SwiftUI.Button {
                testHealthCheck()
            } label: {
                HStack {
                    Label("测试服务器连通性 (Ping)", systemImage: "network")
                        .foregroundColor(.primary)
                    Spacer()
                    if activeAction == .ping {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(activeAction != nil)
            
            SwiftUI.Button {
                triggerDeviceRefresh()
            } label: {
                HStack {
                    Label("刷新服务端设备缓存 (/re/)", systemImage: "arrow.clockwise")
                        .foregroundColor(.primary)
                    Spacer()
                    if activeAction == .refresh {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(activeAction != nil)
            
            SwiftUI.Button {
                queryVersionEndpoint()
            } label: {
                HStack {
                    Label("查询服务端版本 (/ver/)", systemImage: "info.circle")
                        .foregroundColor(.primary)
                    Spacer()
                    if activeAction == .version {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(activeAction != nil)
        }
    }
    
    private func responseInspectorSection(log: SideJITResponseLog) -> some View {
        Section(header: Text("最近一次服务端响应")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(log.httpMethod)
                        .font(.system(.caption, design: .monospaced).bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(log.endpoint)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(log.statusCode)")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundColor(log.isSuccess ? .green : .red)
                    
                    Text("\(log.latencyMs)ms")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                ScrollView(.vertical, showsIndicators: true) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(log.prettyPayload)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .padding(10)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxHeight: 200)
                #if !os(tvOS)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                #else
                .background(Color.white.opacity(0.1))
                #endif
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.vertical, 4)
            .contextMenu {
                SwiftUI.Button {
                    #if !os(tvOS)
                    UIPasteboard.general.string = log.prettyPayload
                    showCopied()
                    #endif
                } label: {
                    Label("复制响应内容", systemImage: "doc.on.doc")
                }
            }
        }
    }
    
    private var aboutSection: some View {
        Section(header: Text("关于")) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SideJITServer 可通过局域网 Wi-Fi 或 USB 调用电脑端调试服务附加至 iOS 17+ 正在运行的应用。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("在「我的应用」长按开启 JIT 时，SideJITServer 会发送调试附加信号以立即激活高性能即时编译。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
        }
    }
    
    private var copiedToastView: some View {
        Text("已复制到剪贴板")
            .font(.subheadline.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.accentColor))
            .padding(.bottom, 16)
    }
    
    private func showCopied() {
        withAnimation(.spring(response: 0.3)) {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3)) {
                showCopiedToast = false
            }
        }
    }
    
    private func refreshServerState() {
        guard isServerEnabled else {
            connectionStatus = .disabled
            debugLog("[SideJITConfig] refreshServerState: SideJITServer is disabled")
            return
        }
        connectionStatus = .checking
        debugLog("[SideJITConfig] refreshServerState: resolving server URL (customAddress='\(customAddress)')")
        Task {
            let serverURL = await SideJITManager.shared.resolveServerURL()
            debugLog("[SideJITConfig] refreshServerState: resolved serverURL='\(serverURL)'")
            await MainActor.run {
                self.resolvedAddress = serverURL
            }
            await performPing(to: serverURL)
        }
    }
    
    private func performPing(to serverURL: String) async {
        guard let url = URL(string: serverURL) else {
            debugLog("[SideJITConfig] performPing: invalid URL string '\(serverURL)'")
            await MainActor.run {
                self.connectionStatus = .disconnected(reason: "Invalid URL")
            }
            return
        }
        
        let start = Date()
        var request = URLRequest(url: url)
        request.timeoutInterval = AppConstants.SideJIT.timeout
        debugLog("[SideJITConfig] performPing: sending GET request to \(url) (timeout: \(AppConstants.SideJIT.timeout)s)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200
            let payload = String(data: data, encoding: .utf8) ?? "<binary data>"
            debugLog("[SideJITConfig] performPing: success from \(url) (status=\(status), latency=\(latency)ms, bytes=\(data.count)):\n\(payload.prettyPrintedJSON)")
            
            await MainActor.run {
                if status >= 200 && status < 400 {
                    self.connectionStatus = .ready(latencyMs: latency, address: serverURL)
                } else {
                    self.connectionStatus = .disconnected(reason: "HTTP \(status)")
                }
                self.latestLog = SideJITResponseLog(
                    timestamp: Date(),
                    endpoint: "/",
                    httpMethod: "GET",
                    statusCode: status,
                    latencyMs: latency,
                    rawPayload: payload.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        } catch {
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            debugLog("[SideJITConfig] performPing: request failed for \(url) after \(latency)ms with error: \(error)")
            await MainActor.run {
                self.connectionStatus = .disconnected(reason: error.localizedDescription)
                self.latestLog = SideJITResponseLog(
                    timestamp: Date(),
                    endpoint: "/",
                    httpMethod: "GET",
                    statusCode: 0,
                    latencyMs: latency,
                    rawPayload: "Error: \(error.localizedDescription)"
                )
            }
        }
    }
    
    private func testHealthCheck() {
        activeAction = .ping
        debugLog("[SideJITConfig] testHealthCheck: user triggered Test Connection (Ping)")
        Task {
            let serverURL = await SideJITManager.shared.resolveServerURL()
            await performPing(to: serverURL)
            await MainActor.run {
                self.activeAction = nil
            }
        }
    }
    
    private func triggerDeviceRefresh() {
        activeAction = .refresh
        debugLog("[SideJITConfig] triggerDeviceRefresh: user triggered Refresh Devices")
        Task {
            let serverURL = await SideJITManager.shared.resolveServerURL()
            guard let url = URL(string: "\(serverURL)/re/") else {
                debugLog("[SideJITConfig] triggerDeviceRefresh: invalid URL for '\(serverURL)/re/'")
                await MainActor.run { self.activeAction = nil }
                return
            }
            
            let start = Date()
            var request = URLRequest(url: url)
            request.timeoutInterval = AppConstants.SideJIT.timeout
            debugLog("[SideJITConfig] triggerDeviceRefresh: requesting \(url)")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let latency = Int(Date().timeIntervalSince(start) * 1000)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 200
                let payload = String(data: data, encoding: .utf8) ?? ""
                debugLog("[SideJITConfig] triggerDeviceRefresh: received status=\(status), latency=\(latency)ms:\n\(payload.prettyPrintedJSON)")
                
                await MainActor.run {
                    if status >= 200 && status < 400 {
                        self.connectionStatus = .ready(latencyMs: latency, address: serverURL)
                    }
                    self.latestLog = SideJITResponseLog(
                        timestamp: Date(),
                        endpoint: "/re/",
                        httpMethod: "GET",
                        statusCode: status,
                        latencyMs: latency,
                        rawPayload: payload.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    self.activeAction = nil
                }
            } catch {
                let latency = Int(Date().timeIntervalSince(start) * 1000)
                debugLog("[SideJITConfig] triggerDeviceRefresh: request failed after \(latency)ms with error: \(error)")
                await MainActor.run {
                    self.latestLog = SideJITResponseLog(
                        timestamp: Date(),
                        endpoint: "/re/",
                        httpMethod: "GET",
                        statusCode: 0,
                        latencyMs: latency,
                        rawPayload: "Error: \(error.localizedDescription)"
                    )
                    self.activeAction = nil
                }
            }
        }
    }
    
    private func queryVersionEndpoint() {
        activeAction = .version
        debugLog("[SideJITConfig] queryVersionEndpoint: user triggered Query Versions")
        Task {
            let serverURL = await SideJITManager.shared.resolveServerURL()
            guard let url = URL(string: "\(serverURL)/ver/") else {
                debugLog("[SideJITConfig] queryVersionEndpoint: invalid URL for '\(serverURL)/ver/'")
                await MainActor.run { self.activeAction = nil }
                return
            }
            
            let start = Date()
            var request = URLRequest(url: url)
            request.timeoutInterval = AppConstants.SideJIT.timeout
            debugLog("[SideJITConfig] queryVersionEndpoint: requesting \(url)")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let latency = Int(Date().timeIntervalSince(start) * 1000)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 200
                let payload = String(data: data, encoding: .utf8) ?? ""
                debugLog("[SideJITConfig] queryVersionEndpoint: received status=\(status), latency=\(latency)ms:\n\(payload.prettyPrintedJSON)")
                
                await MainActor.run {
                    self.latestLog = SideJITResponseLog(
                        timestamp: Date(),
                        endpoint: "/ver/",
                        httpMethod: "GET",
                        statusCode: status,
                        latencyMs: latency,
                        rawPayload: payload.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    self.activeAction = nil
                }
            } catch {
                let latency = Int(Date().timeIntervalSince(start) * 1000)
                debugLog("[SideJITConfig] queryVersionEndpoint: request failed after \(latency)ms with error: \(error)")
                await MainActor.run {
                    self.latestLog = SideJITResponseLog(
                        timestamp: Date(),
                        endpoint: "/ver/",
                        httpMethod: "GET",
                        statusCode: 0,
                        latencyMs: latency,
                        rawPayload: "Error: \(error.localizedDescription)"
                    )
                    self.activeAction = nil
                }
            }
        }
    }
}
