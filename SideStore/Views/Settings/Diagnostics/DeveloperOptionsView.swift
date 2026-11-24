//
//  DeveloperOptionsView.swift
//  SideStore
//
//  Created by Magesh K on 8/2/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers
#if !os(tvOS)
import WidgetKit
#else
import TVServices
#endif
import SideSign
import MinimuxerCommon

private extension Color {
    static let settingsRowBackground = Color.white.opacity(0.15)
    static let settingsDivider = Color.white.opacity(0.15)
}

struct DeveloperOptionsView: View {
    @State private var responseCachingDisabled: Bool = UserDefaults.standard.responseCachingDisabled
    @State private var isVerboseOperationsLoggingEnabled: Bool = UserDefaults.standard.isVerboseOperationsLoggingEnabled
    @State private var isSideStoreVerboseLoggingEnabled: Bool = UserDefaults.standard.isSideStoreVerboseLoggingEnabled
    @State private var isAltWidgetVerboseLoggingEnabled: Bool = WidgetDataManager.shared.isVerboseLoggingEnabled
    @State private var isSideSignVerboseLoggingEnabled: Bool = UserDefaults.standard.isAltSignVerboseLoggingEnabled
    @State private var isMinimuxerVerboseLoggingEnabled: Bool = UserDefaults.standard.isMinimuxerVerboseLoggingEnabled
    @State private var isRotateLogsOnStartupEnabled: Bool = UserDefaults.standard.isRotateLogsOnStartupEnabled
    @State private var recreateDatabaseOnNextStart: Bool = UserDefaults.standard.recreateDatabaseOnNextStart
    @State private var alwaysShowWireGuardConfig: Bool = UserDefaults.standard.alwaysShowWireGuardConfig
    @State private var acceptIPv6ConnectionConfig: Bool = UserDefaults.standard.acceptIPv6ConnectionConfig
    @State private var isAutoRetryRemotePairingPortEnabled: Bool = UserDefaults.standard.isAutoRetryRemotePairingPortEnabled
    @State private var tcpProbeTimeoutText: String = ""
    
    @State private var isExportingDB: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var showClearRefreshAttemptsConfirmation: Bool = false
    @State private var showClearKeychainConfirmation: Bool = false
    @State private var showExportPasswordPrompt: Bool = false
    @State private var exportCertPassword: String = ""
    @State private var showOnboardingSheet: Bool = false
    @State private var isDumpingProfiles: Bool = false
    @State private var showDumpProfilesAlert: Bool = false
    @State private var dumpProfilesAlertMessage: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section 1: Logging & Diagnostics
                VStack(alignment: .leading, spacing: 8) {
                    Text("日志记录与诊断")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        toggleRow(title: "禁用网络请求响应缓存", isOn: Binding(
                            get: { responseCachingDisabled },
                            set: { newValue in
                                responseCachingDisabled = newValue
                                UserDefaults.standard.responseCachingDisabled = newValue
                            }
                        ))
                        
                        divider
                        
                        toggleRow(title: "每次启动时自动轮转分割日志文件", isOn: Binding(
                            get: { isRotateLogsOnStartupEnabled },
                            set: { newValue in
                                isRotateLogsOnStartupEnabled = newValue
                                UserDefaults.standard.isRotateLogsOnStartupEnabled = newValue
                                let suffixFormat: SuffixFormat = newValue ? .timestamp : .none
                                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                                    appDelegate.consoleLog.updateConfiguration(baseName: "console", suffixFormat: suffixFormat, policy: .immediate)
                                }
                            }
                        ))
                        
                        divider
                        
                        toggleRow(title: "开启 SideStore 详细调试日志", isOn: Binding(
                            get: { isSideStoreVerboseLoggingEnabled },
                            set: { newValue in
                                isSideStoreVerboseLoggingEnabled = newValue
                                UserDefaults.standard.isSideStoreVerboseLoggingEnabled = newValue
                                SideStoreLogging.setLogging(newValue)
                            }
                        ))
                        
                        divider
                        
                        #if !os(tvOS)
                        let title = "开启桌面小组件详细日志"
                        #else
                        let title = "开启 Top Shelf 详细日志"
                        #endif
                        toggleRow(title: title, isOn: Binding(
                            get: { isAltWidgetVerboseLoggingEnabled },
                            set: { newValue in
                                isAltWidgetVerboseLoggingEnabled = newValue
                                WidgetDataManager.shared.isVerboseLoggingEnabled = newValue
                            }
                        ))
                        
                        divider
                        
                        toggleRow(title: "开启 SideSign 详细签名日志", isOn: Binding(
                            get: { isSideSignVerboseLoggingEnabled },
                            set: { newValue in
                                isSideSignVerboseLoggingEnabled = newValue
                                UserDefaults.standard.isAltSignVerboseLoggingEnabled = newValue
                                SideSignLogging.setLogging(newValue)
                            }
                        ))
                        
                        divider
                        
                        toggleRow(title: "开启 Minimuxer 详细通信日志", isOn: Binding(
                            get: { isMinimuxerVerboseLoggingEnabled },
                            set: { newValue in
                                isMinimuxerVerboseLoggingEnabled = newValue
                                UserDefaults.standard.isMinimuxerVerboseLoggingEnabled = newValue
                                minimuxerSetLogging(newValue)
                            }
                        ))
                        
                        divider
                        
                        toggleRow(title: "开启操作流水线详细日志", isOn: Binding(
                            get: { isVerboseOperationsLoggingEnabled },
                            set: { newValue in
                                isVerboseOperationsLoggingEnabled = newValue
                                UserDefaults.standard.isVerboseOperationsLoggingEnabled = newValue
                            }
                        ))
                        
                        divider
                        
                        NavigationLink(destination: OperationsLoggingControlView()) {
                            HStack {
                                Text("分步流水线日志开关")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }
                
                // Section: Widget Options
                VStack(alignment: .leading, spacing: 8) {
                    #if !os(tvOS)
                    let title = "桌面小组件调试"
                    #else
                    let title = "TOP SHELF 调试"
                    #endif
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        SwiftUI.Button(action: { triggerReloadAllWidgets() }) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)

                                #if !os(tvOS)
                                let title = "强制刷新全部小组件"
                                #else
                                let title = "强制刷新 Top Shelf"
                                #endif
                                Text(title)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                        
                        divider
                        
                        SwiftUI.Button(action: { triggerRotateWidgetLog() }) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                #if !os(tvOS)
                                let title = "立即归档轮转小组件日志"
                                #else
                                let title = "立即归档轮转 Top Shelf 日志"
                                #endif
                                Text(title)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }
                
                // Section 2: Database Options
                VStack(alignment: .leading, spacing: 8) {
                    Text("数据库与钥匙串维护")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        SwiftUI.Button(action: { exportDatabase() }) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("导出 CoreData 数据库副本")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                if isExportingDB {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                        .disabled(isExportingDB)
                        
                        divider
                        
                        SwiftUI.Button(action: { showClearRefreshAttemptsConfirmation = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(red: 1.0, green: 0.27, blue: 0.27))
                                Text("清空后台刷新历史记录")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(Color(red: 1.0, green: 0.27, blue: 0.27))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                        
                        divider
                        
                        SwiftUI.Button(action: { showDeleteConfirmation = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "trash")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(red: 1.0, green: 0.27, blue: 0.27))
                                Text("删除数据库并退出")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(Color(red: 1.0, green: 0.27, blue: 0.27))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                        
                        divider
                        
                        SwiftUI.Button(action: { showClearKeychainConfirmation = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "key")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(red: 1.0, green: 0.27, blue: 0.27))
                                Text("清空本应用全部钥匙串凭据")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(Color(red: 1.0, green: 0.27, blue: 0.27))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                        
                        divider
                        
                        toggleRow(title: "下次启动时清空重建数据库", isOn: Binding(
                            get: { recreateDatabaseOnNextStart },
                            set: { newValue in
                                recreateDatabaseOnNextStart = newValue
                                UserDefaults.standard.recreateDatabaseOnNextStart = newValue
                            }
                        ))
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }
                
                // Section 3: WireGuard Configuration
                VStack(alignment: .leading, spacing: 8) {
                    Text("WIREGUARD 调试控制")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        SwiftUI.Button(action: { triggerStartEMProxy() }) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("手动启动 EMProxy")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                        
                        divider
                        
                        SwiftUI.Button(action: { triggerStopEMProxy() }) {
                            HStack(spacing: 12) {
                                Image(systemName: "stop.circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("手动停止 EMProxy")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                        
                        divider
                        
                        toggleRow(title: "显示旧版 WireGuard 配置项", isOn: Binding(
                            get: { alwaysShowWireGuardConfig },
                            set: { newValue in
                                alwaysShowWireGuardConfig = newValue
                                UserDefaults.standard.alwaysShowWireGuardConfig = newValue
                            }
                        ))
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("后台保活服务")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        SwiftUI.Button(action: { triggerStartBackgroundService() }) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("启动后台保活服务")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                        
                        divider
                        
                        SwiftUI.Button(action: { triggerStopBackgroundService() }) {
                            HStack(spacing: 12) {
                                Image(systemName: "stop.circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("停止后台保活服务")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }
                
                // Section: Device (TCP) Probe Timeout
                VStack(alignment: .leading, spacing: 8) {
                    Text("设备连通性探测超时 (TCP)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Text("超时时间 (毫秒)")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            TextField("ms", text: $tcpProbeTimeoutText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.white)
                                .font(.system(size: 17))
                                .frame(width: 90)
                                .onChange(of: tcpProbeTimeoutText) { newValue in
                                    let filtered = newValue.filter { "0123456789".contains($0) }
                                    if filtered != newValue {
                                        tcpProbeTimeoutText = filtered
                                    }
                                    if let timeout = Int(filtered), timeout > 0 {
                                        minimuxerSetDeviceProbeTimeout(timeout)
                                    }
                                }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        
                        divider
                        
                        SwiftUI.Button(action: {
                            let defaultTimeout = AppConstants.Minimuxer.defaultTCPProbeTimeoutMs
                            tcpProbeTimeoutText = String(defaultTimeout)
                            minimuxerSetDeviceProbeTimeout(defaultTimeout)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("恢复默认值 (\(AppConstants.Minimuxer.defaultTCPProbeTimeoutMs) ms)")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }
                
                // Section: Connection Config
                VStack(alignment: .leading, spacing: 8) {
                    Text("底层连接高级参数")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        toggleRow(title: "允许在连接配置中填写 IPv6 地址", isOn: Binding(
                            get: { acceptIPv6ConnectionConfig },
                            set: { newValue in
                                acceptIPv6ConnectionConfig = newValue
                                UserDefaults.standard.acceptIPv6ConnectionConfig = newValue
                            }
                        ))
                        
                        divider
                        
                        toggleRow(title: "远程配对端口连接失败时自动重试探测", isOn: Binding(
                            get: { isAutoRetryRemotePairingPortEnabled },
                            set: { newValue in
                                isAutoRetryRemotePairingPortEnabled = newValue
                                UserDefaults.standard.isAutoRetryRemotePairingPortEnabled = newValue
                            }
                        ))
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }
                
                #if DEBUG
                // Section 3: Account Management
                VStack(alignment: .leading, spacing: 8) {
                    Text("账号数据调试导入/导出")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        SwiftUI.Button(action: { showImportAccountPicker() }) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("导入账号配置 (.sideconf / JSON)")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                        
                        divider
                        
                        SwiftUI.Button(action: {
                            if AuthManager.shared.currentAppleID == nil ||
                               AuthManager.shared.password == nil ||
                               CertificateManager.shared.activeCertificate == nil {
                                if let top = UIApplication.shared.topViewController() {
                                    let toastView = ToastView(text: NSLocalizedString("导出账号失败！", comment: ""), detailText: "未找到已登录账号或缺少必要凭据。")
                                    toastView.show(in: top)
                                }
                            } else {
                                exportCertPassword = ""
                                showExportPasswordPrompt = true
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("导出账号配置 (.sideconf)")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }
                #endif
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("描述文件调试提取")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)

                    VStack(spacing: 0) {
                        SwiftUI.Button(action: {
                            Task {
                                await dumpProvisioningProfiles()
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.down.doc")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("导出全部本地描述文件副本")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                if isDumpingProfiles {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                        .disabled(isDumpingProfiles)
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("首次引导页调试")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)

                    VStack(spacing: 0) {
                        SwiftUI.Button(action: { showOnboardingSheet = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("重新进入首次欢迎引导页")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                        .sheet(isPresented: $showOnboardingSheet) {
                            OnboardingView(onFinish: {
                                showOnboardingSheet = false
                            })
                        }

                        divider

                        SwiftUI.Button(action: {
                            UserDefaults.standard.hasCompletedOnboarding = false
                            UserDefaults.standard.synchronize()
                            if let top = UIApplication.shared.topViewController() {
                                let toastView = ToastView(text: NSLocalizedString("已重置引导状态，下次启动将展示欢迎引导", comment: ""), detailText: nil)
                                toastView.show(in: top)
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("重置首次引导完成标记")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .settingsBackground).ignoresSafeArea())
        .navigationTitle("开发者选项")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .alert("删除数据库并退出", isPresented: $showDeleteConfirmation) {
            SwiftUI.Button("删除数据库并退出", role: .destructive) {
                _ = DatabaseManager.deleteDatabase()
                exit(0)
            }
            SwiftUI.Button("取消", role: .cancel) {}
        } message: {
            Text("删除数据库将清空 SideStore 中记录的所有已安装应用列表与软件源（已安装到桌面的应用本身不会被卸载）。")
        }
        .alert("清空后台刷新历史记录", isPresented: $showClearRefreshAttemptsConfirmation) {
            SwiftUI.Button("清空", role: .destructive) {
                clearRefreshAttempts()
            }
            SwiftUI.Button("取消", role: .cancel) {}
        } message: {
            Text("确定要清空所有历史刷新尝试记录吗？")
        }
        #if DEBUG
        .alert("导出账号配置", isPresented: $showExportPasswordPrompt) {
            SecureField("证书保护密码", text: $exportCertPassword)
            SwiftUI.Button("导出") {
                exportAccountJSON(password: exportCertPassword)
            }
            SwiftUI.Button("取消", role: .cancel) {}
        } message: {
            Text("请设置导出证书所使用的保护密码。")
        }
        #endif
        .alert("清空本应用全部钥匙串凭据", isPresented: $showClearKeychainConfirmation) {
            SwiftUI.Button("全部清空", role: .destructive) {
                Keychain.shared.clearAll()
            }
            SwiftUI.Button("取消", role: .cancel) {}
        } message: {
            Text("确定要清除当前 SideStore 实例保存在系统钥匙串中的所有账号、证书与配对凭据吗？")
        }
        .alert("导出描述文件结果", isPresented: $showDumpProfilesAlert) {
            SwiftUI.Button("好", role: .cancel) {}
        } message: {
            Text(dumpProfilesAlertMessage)
        }
        .onAppear {
            tcpProbeTimeoutText = String(minimuxerGetDeviceProbeTimeout())
        }
    }
    
    private func dumpProvisioningProfiles() async {
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        isDumpingProfiles = true
        defer { isDumpingProfiles = false }
        do {
            let zipPath = try await safeDumpProfiles(docsURL.path)
            let fileName = URL(fileURLWithPath: zipPath).lastPathComponent
            dumpProfilesAlertMessage = "描述文件已导出至：\n\(fileName)"
            showDumpProfilesAlert = true
        } catch {
            dumpProfilesAlertMessage = "导出描述文件失败：\n\(error.localizedDescription)"
            showDumpProfilesAlert = true
        }
    }
    
    #if DEBUG
    private func showImportAccountPicker() {
        guard let top = UIApplication.shared.topViewController() else { return }
        #if !os(tvOS)
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType(filenameExtension: "sideconf")!, .json], asCopy: false)
        ImportExport.documentPickerHandler = DocumentPickerHandler { selectedURL in
            guard let url = selectedURL else { return }
            Task { @MainActor in
                do {
                    try await ImportExport.importAccountJSON(from: url)
                    let email = AuthManager.shared.currentAppleID ?? ""
                    let toastView = ToastView(text: NSLocalizedString("已成功导入账号「\(email)」！", comment: ""), detailText: "SideStore 现已就绪可用！")
                    toastView.show(in: top)
                } catch {
                    let toastView = ToastView(text: NSLocalizedString("导入账号配置失败！", comment: ""), detailText: error.localizedDescription)
                    toastView.show(in: top)
                }
            }
        }
        picker.delegate = ImportExport.documentPickerHandler
        top.present(picker, animated: true)
        #else
        TVWebFileTransferManager.shared.startImport(
            acceptedExtensions: ["sideconf", "json"],
            title: "导入账号配置",
            presentingVC: top
        ) { selectedURL in
            guard let url = selectedURL else { return }
            Task { @MainActor in
                do {
                    try await ImportExport.importAccountJSON(from: url)
                    let email = AuthManager.shared.currentAppleID ?? ""
                    let toastView = ToastView(text: NSLocalizedString("已成功导入账号「\(email)」！", comment: ""), detailText: "SideStore 现已就绪可用！")
                    toastView.show(in: top)
                } catch {
                    let toastView = ToastView(text: NSLocalizedString("导入账号配置失败！", comment: ""), detailText: error.localizedDescription)
                    toastView.show(in: top)
                }
            }
        }
        #endif
    }
    
    private func exportAccountJSON(password: String) {
        guard let top = UIApplication.shared.topViewController() else { return }
        guard let account = ImportExport.exportAccountJSON(password: password) else {
            let toastView = ToastView(text: NSLocalizedString("导出账号失败！", comment: ""), detailText: "未找到已登录账号或缺少必要凭据。")
            toastView.show(in: top)
            return
        }
        
        guard let accountData = try? Foundation.JSONEncoder().encode(account) else {
            let toastView = ToastView(text: NSLocalizedString("导出账号数据失败！", comment: ""), detailText: "账号数据格式异常。")
            toastView.show(in: top)
            return
        }
        
        let tmpPath = FileManager.default.temporaryDirectory.appendingPathComponent("\(account.email).sideconf")
        do {
            try accountData.write(to: tmpPath)
            #if !os(tvOS)
            let exportVC = UIDocumentPickerViewController(forExporting: [tmpPath], asCopy: false)
            top.present(exportVC, animated: true)
            #else
            TVWebFileTransferManager.shared.startExport(fileURL: tmpPath, title: "导出账号配置", presentingVC: top)
            #endif
        } catch {
            let toastView = ToastView(text: NSLocalizedString("导出账号失败！", comment: ""), detailText: error.localizedDescription)
            toastView.show(in: top)
        }
    }
    #endif
    
    private func clearRefreshAttempts() {
        let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        context.perform {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = RefreshAttempt.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            _ = try? context.execute(deleteRequest)
            try? context.save()
        }
    }
    
    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 50)
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.settingsDivider)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }
    
    private func exportDatabase() {
        guard !isExportingDB else { return }
        isExportingDB = true
        
        Task {
            do {
                let exportedURL = try await CoreDataHelper.exportCoreDataStore()
                debugLog("[DeveloperOptionsView] ExportedURL: \(exportedURL)")
                await MainActor.run {
                    isExportingDB = false
                }
            } catch {
                debugLog("[DeveloperOptionsView] Export error: \(error)")
                await MainActor.run {
                    isExportingDB = false
                }
            }
        }
    }

    
    private func triggerStartEMProxy() {
        guard let top = UIApplication.shared.topViewController() else { return }
        Task {
            do {
                try await startEMProxy()
                await MainActor.run {
                    let toastView = ToastView(text: NSLocalizedString("已启动 EMProxy", comment: ""), detailText: "EMProxy 本地回环代理正在运行。")
                    toastView.show(in: top)
                }
            } catch {
                await MainActor.run {
                    let toastView = ToastView(text: NSLocalizedString("启动 EMProxy 失败！", comment: ""), detailText: error.localizedDescription)
                    toastView.show(in: top)
                }
            }
        }
    }
    
    private func triggerStopEMProxy() {
        guard let top = UIApplication.shared.topViewController() else { return }
        Task {
            do {
                try await stopEMProxy()
                await MainActor.run {
                    let toastView = ToastView(text: NSLocalizedString("已停止 EMProxy", comment: ""), detailText: "EMProxy 本地回环代理已停止。")
                    toastView.show(in: top)
                }
            } catch {
                await MainActor.run {
                    let toastView = ToastView(text: NSLocalizedString("停止 EMProxy 失败！", comment: ""), detailText: error.localizedDescription)
                    toastView.show(in: top)
                }
            }
        }
    }

    private func triggerStartBackgroundService() {
        guard let top = UIApplication.shared.topViewController() else { return }
        let started = BackgroundServiceManager.ensureBackgroundServicesStarted()
        let modeName = UserDefaults.standard.backgroundServiceMode.displayName
        if started {
            let toastView = ToastView(text: NSLocalizedString("已启动后台保活服务", comment: ""), detailText: "\(modeName) 后台保活服务正在运行。")
            toastView.show(in: top)
        } else {
            let toastView = ToastView(text: NSLocalizedString("后台保活服务未启用", comment: ""), detailText: "请先前往「高级自定义」开启后台常驻保活。")
            toastView.show(in: top)
        }
    }

    private func triggerStopBackgroundService() {
        guard let top = UIApplication.shared.topViewController() else { return }
        BackgroundServiceManager.stop()
        let toastView = ToastView(text: NSLocalizedString("已停止后台保活服务", comment: ""), detailText: "后台常驻保活服务已停止。")
        toastView.show(in: top)
    }
    
    private func triggerReloadAllWidgets() {
        #if !os(tvOS)
        WidgetCenter.shared.reloadAllTimelines()
        let title = NSLocalizedString("已刷新全部桌面小组件", comment: "")
        let detail = "已触发全部桌面小组件的时间线刷新。"
        #else
        NotificationCenter.default.post(name: .TVTopShelfItemsDidChange, object: nil)
        let title = NSLocalizedString("已刷新 Top Shelf", comment: "")
        let detail = "已触发 Top Shelf 刷新。"
        #endif
        if let top = UIApplication.shared.topViewController() {
            let toastView = ToastView(text: title, detailText: detail)
            toastView.show(in: top)
        }
    }
    
    private func triggerRotateWidgetLog() {
        guard let top = UIApplication.shared.topViewController() else { return }
        #if !os(tvOS)
        let logName = "Widget"
        #else
        let logName = "Top Shelf"
        #endif
        do {
            if let rotatedURL = try WidgetLogManager.rotateLog() {
                let toastView = ToastView(text: NSLocalizedString("已归档轮转 \(logName) 日志", comment: ""), detailText: "已归档保存至 WidgetLogs/\(rotatedURL.lastPathComponent)")
                toastView.show(in: top)
            } else {
                let toastView = ToastView(text: NSLocalizedString("\(logName) 日志为空", comment: ""), detailText: "当前日志为空，无需轮转。")
                toastView.show(in: top)
            }
        } catch {
            let toastView = ToastView(text: NSLocalizedString("轮转日志失败", comment: ""), detailText: error.localizedDescription)
            toastView.show(in: top)
        }
    }
}
