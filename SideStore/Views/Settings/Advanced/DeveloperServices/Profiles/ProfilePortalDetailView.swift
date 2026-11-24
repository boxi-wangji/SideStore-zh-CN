//
//  ProfilePortalDetailView.swift
//  SideStore
//
//  Created by Magesh K on 2/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct ProfilePortalDetailView: View {
    let profile: ALTListedProvisioningProfile
    @ObservedObject var viewModel: DeveloperServicesViewModel
    weak var presentingViewController: UIViewController?
    @Environment(\.presentationMode) var presentationMode

    @State private var editedName: String = ""
    @State private var selectedAppIDId: String = ""
    @State private var selectedCertificateIDs: Set<String> = []
    @State private var selectedDeviceIDs: Set<String> = []

    @State private var customCertInput: String = ""
    @State private var customDeviceInput: String = ""

    @State private var showDeleteAlert = false
    @State private var exportProfileURL: URL? = nil

    private var isExpired: Bool {
        profile.dateExpire < Date()
    }

    private var hasChanges: Bool {
        let nameChanged = !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && editedName != profile.name
        let originalAppID = profile.appId?.appIdId ?? profile.appId?.identifier ?? ""
        let appIDChanged = !selectedAppIDId.isEmpty && selectedAppIDId != originalAppID
        let originalDevices = Set(profile.deviceIds ?? [])
        let devicesChanged = selectedDeviceIDs != originalDevices
        return nameChanged || appIDChanged || devicesChanged
    }

    private var canSave: Bool {
        !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedAppIDId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedCertificateIDs.isEmpty &&
        !selectedDeviceIDs.isEmpty &&
        !viewModel.isActionLoading
    }

    var body: some View {
        List {
            Section(header: Text("描述文件信息"), footer: Text("可修改名称或调整关联的证书与设备并重新签发描述文件。")) {
                HStack {
                    Text("名称")
                        .foregroundColor(.secondary)
                        .frame(width: 100, alignment: .leading)
                    TextField("描述文件名称", text: $editedName)
                }

                InfoRow(label: "UUID", value: profile.uuid.uuidString)
                if let identifier = profile.identifier {
                    InfoRow(label: "标识符", value: identifier)
                }
                if let profType = profile.profileType {
                    InfoRow(label: "类型", value: profType.displayName)
                } else if let rawType = profile.type {
                    InfoRow(label: "类型", value: rawType)
                }
                if let isTeam = profile.isTeamProfile {
                    InfoRow(label: "管理方式", value: isTeam ? "Xcode 自动托管" : "手动创建")
                }
                InfoRow(label: "状态", value: isExpired ? "Expired" : (profile.status ?? "Active"), valueColor: isExpired ? .red : .primary)
                InfoRow(label: "到期时间", value: formatDate(profile.dateExpire), valueColor: isExpired ? .red : .primary)
            }

            Section(header: Text("关联的应用 ID"), footer: Text("从团队已注册的应用 ID 中选择，或手动输入标识符。")) {
                if !viewModel.appIDs.isEmpty {
                    Picker("团队应用 ID", selection: $selectedAppIDId) {
                        Text("选择应用 ID").tag("")
                        ForEach(viewModel.appIDs, id: \.identifier) { appID in
                            Text("\(appID.name) (\(appID.bundleIdentifier))").tag(appID.identifier)
                        }
                    }
                }

                HStack {
                    Text("应用 ID 标识码")
                        .foregroundColor(.secondary)
                        .frame(width: 100, alignment: .leading)
                    TextField("输入 App ID 标识码（例如 R7V954WR9W）", text: $selectedAppIDId)
                        .font(.system(.subheadline, design: .monospaced))
                }
            }

            Section(header: Text("关联证书 (\(selectedCertificateIDs.count))"), footer: Text("勾选授权签名的证书，或手动添加证书 ID。")) {
                if viewModel.certificates.isEmpty {
                    Text("当前团队下未找到任何证书。")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(viewModel.certificates, id: \.serialNumber) { cert in
                        let certID = cert.identifier ?? cert.serialNumber
                        SwiftUI.Button {
                            if selectedCertificateIDs.contains(certID) {
                                selectedCertificateIDs.remove(certID)
                            } else {
                                selectedCertificateIDs.insert(certID)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cert.commonName ?? cert.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text("Serial: \(cert.serialNumber)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    let hasKey = ProfileManager.shared.hasPrivateKey(for: cert)
                                    HStack(spacing: 4) {
                                        Text("密钥：\(hasKey ? "公钥 + 私钥" : "仅公钥")")
                                            .font(.caption2)
                                            .foregroundColor(hasKey ? .green : .secondary)
                                        if hasKey {
                                            Image(systemName: "key.fill")
                                                .font(.system(size: 9))
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                                Spacer()
                                if selectedCertificateIDs.contains(certID) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("手动输入证书 ID", text: $customCertInput)
                        .font(.system(.subheadline, design: .monospaced))
                    SwiftUI.Button("添加") {
                        let trimmed = customCertInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            selectedCertificateIDs.insert(trimmed)
                            customCertInput = ""
                        }
                    }
                    .disabled(customCertInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section(header: HStack {
                Text("关联设备 (\(selectedDeviceIDs.count))")
                Spacer()
                if !viewModel.devices.isEmpty {
                    SwiftUI.Button(selectedDeviceIDs.count >= viewModel.devices.count ? "取消全选" : "全选") {
                        if selectedDeviceIDs.count >= viewModel.devices.count {
                            selectedDeviceIDs.removeAll()
                        } else {
                            selectedDeviceIDs = Set(viewModel.devices.compactMap { $0.deviceID ?? $0.identifier })
                        }
                    }
                    .font(.caption)
                }
            }, footer: Text("勾选允许运行应用的设备，或手动添加设备 ID / UDID。")) {
                if viewModel.devices.isEmpty {
                    Text("当前团队暂无已注册设备。")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(viewModel.devices, id: \.identifier) { device in
                        let devID = device.deviceID ?? device.identifier
                        let isSelected = selectedDeviceIDs.contains(devID) || selectedDeviceIDs.contains(device.identifier)
                        SwiftUI.Button {
                            if isSelected {
                                selectedDeviceIDs.remove(devID)
                                selectedDeviceIDs.remove(device.identifier)
                            } else {
                                selectedDeviceIDs.insert(devID)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text(device.identifier)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("手动添加设备 ID / UDID", text: $customDeviceInput)
                        .font(.system(.subheadline, design: .monospaced))
                    SwiftUI.Button("添加") {
                        let trimmed = customDeviceInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            selectedDeviceIDs.insert(trimmed)
                            customDeviceInput = ""
                        }
                    }
                    .disabled(customDeviceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if hasChanges {
                Section {
                    SwiftUI.Button {
                        Task {
                            let success = await viewModel.updateProfile(
                                profile,
                                name: editedName.trimmingCharacters(in: .whitespacesAndNewlines),
                                appIDId: selectedAppIDId.trimmingCharacters(in: .whitespacesAndNewlines),
                                certificateIDs: Array(selectedCertificateIDs),
                                deviceIDs: Array(selectedDeviceIDs),
                                type: profile.profileType,
                                presentingViewController: presentingViewController
                            )
                            if success {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isActionLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("保存更改并重新签发")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }

            Section {
                SwiftUI.Button {
                    Task {
                        guard let downloaded = await viewModel.downloadProfile(profile: profile) else { return }
                        let safeName = profile.name.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).mobileprovision")
                        do {
                            try downloaded.data.write(to: tempURL)
                            exportProfileURL = tempURL
                        } catch {
                            debugLog("[ProfilePortalDetailView] Failed to write profile to temp: \(error)")
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isActionLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.down.doc")
                            Text("下载描述文件 (.mobileprovision)")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(viewModel.isActionLoading)
            }

            Section {
                SwiftUI.Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                        Text("从开发者中心删除此描述文件")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        #if !os(tvOS)
        .listStyle(InsetGroupedListStyle())
        #else
        .listStyle(GroupedListStyle())
        #endif
        .navigationTitle(profile.name)
        .refreshable {
            await viewModel.fetchProfiles(presentingViewController: presentingViewController, isPullToRefresh: true)
        }
        .onAppear {
            if editedName.isEmpty {
                editedName = profile.name
            }
            if selectedAppIDId.isEmpty {
                selectedAppIDId = profile.appId?.appIdId ?? profile.appId?.identifier ?? ""
            }
            if selectedDeviceIDs.isEmpty, let devIDs = profile.deviceIds {
                selectedDeviceIDs = Set(devIDs)
            }
            if selectedCertificateIDs.isEmpty {
                selectedCertificateIDs = Set(viewModel.certificates.compactMap { $0.identifier ?? $0.serialNumber })
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("删除描述文件？"),
                message: Text("确定要从 Apple 开发者中心删除描述文件「\(profile.name)」吗？"),
                primaryButton: .destructive(Text("删除")) {
                    Task {
                        let success = await viewModel.deleteProfile(profile, presentingViewController: presentingViewController)
                        if success {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .developerServicesToast(viewModel: viewModel)
        .sheet(isPresented: Binding<Bool>(
            get: { exportProfileURL != nil },
            set: { if !$0 { exportProfileURL = nil } }
        )) {
            if let url = exportProfileURL {
                ActivityViewController(activityItems: [url])
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
