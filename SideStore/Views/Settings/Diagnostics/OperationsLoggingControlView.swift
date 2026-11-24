//
//  OperationsLoggingControlView.swift
//  SideStore
//
//  Created by Magesh K on 14/01/25.
//  Copyright © 2025 SideStore. All rights reserved.
//

import SwiftUI

private extension Color {
    static let settingsRowBackground = Color.white.opacity(0.15)
    static let settingsDivider = Color.white.opacity(0.15)
}

private let pipelineStepToggles: [(name: String, step: PipelineStep)] = [
    ("备份应用数据",                            .backupAppData),
    ("缓存安装包",                              .cacheApp),
    ("更换应用图标",                            .changeAppIcon),
    ("清理临时解包目录",                        .cleanStagedApp),
    ("停用应用",                                .deactivateApp),
    ("下载安装包",                              .downloadApp),
    ("导出重签 IPA",                            .exportResignedIPA),
    ("申请签名描述文件",                        .fetchProvisioningProfiles),
    ("安装应用到设备",                          .installApp),
    ("安装前环境预检",                          .preflightChecks),
    ("准备应用扩展包名",                        .prepareAppExtensionBundleIDs),
    ("续期刷新应用",                            .refreshApp),
    ("移除应用记录",                            .removeApp),
    ("移除应用扩展",                            .removeAppExtensions),
    ("清理残留备份数据",                        .removeBackupData),
    ("重签名应用",                              .resignApp),
    ("恢复应用备份数据",                        .restoreAppData),
    ("传输安装包到本机服务",                    .sendApp),
    ("预处理解包应用",                          .stageApp),
    ("准备备份辅助应用",                        .stageBackupApp),
    ("更新签名证书状态",                        .updateAppCertificate),
    ("应用用户自定义项",                        .userCustomization),
    ("校验安装包与权限",                        .verifyApp),
    ("校验签名证书有效性",                      .verifyCertificate),
    ("打包生成 IPA",                            .createIPA),
]

private let standaloneStepToggles: [(name: String, step: StandaloneStep)] = [
    ("Apple ID 登录认证",                       .signIn),
    ("后台自动刷新任务",                        .backgroundRefreshApps),
    ("清理数据缓存",                            .clearAppCache),
    ("开启 JIT 加速",                           .enableJIT),
    ("同步应用 ID 列表",                        .syncAppIDs),
    ("拉取更新软件源",                          .fetchSource),
    ("注册签名到期提醒通知",                    .scheduleExpirationWarningNotification),
]

struct OperationsLoggingControlView: View {
    @ObservedObject private var viewModel = OperationsLoggingViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Standalone Steps
                VStack(alignment: .leading, spacing: 8) {
                    Text("独立任务日志开关")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(standaloneStepToggles.enumerated()), id: \.element.name) { index, entry in
                            if index > 0 {
                                divider
                            }
                            stepToggle(entry.name, step: entry.step)
                        }
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }
                
                // Pipeline Steps
                VStack(alignment: .leading, spacing: 8) {
                    Text("安装/刷新流水线步骤日志开关")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(pipelineStepToggles.enumerated()), id: \.element.name) { index, entry in
                            if index > 0 {
                                divider
                            }
                            stepToggle(entry.name, step: entry.step)
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
        .navigationTitle("分步日志控制")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private func stepToggle(_ title: String, step: some OperationStep) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Toggle("", isOn: Binding(
                get: { OperationsLoggingControl.isStepLoggingEnabled(for: step) },
                set: { value in
                    OperationsLoggingControl.setStepLoggingEnabled(for: step, value: value)
                    viewModel.refresh()
                }
            ))
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
}

private final class OperationsLoggingViewModel: ObservableObject {
    func refresh() {
        objectWillChange.send()
    }
}
