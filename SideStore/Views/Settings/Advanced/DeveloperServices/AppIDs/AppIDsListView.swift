//
//  AppIDsListView.swift
//  SideStore
//
//  Created by Magesh K on 2/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct AppIDsListView: View {
    @ObservedObject var viewModel: DeveloperServicesViewModel
    weak var presentingViewController: UIViewController?

    @State private var searchText = ""
    @State private var showRegisterSheet = false
    @State private var newAppIDName = ""
    @State private var newAppIDBundleID = ""

    @State private var appIDToDelete: ALTAppID? = nil
    @State private var showDeleteConfirmation = false

    private var filteredAppIDs: [ALTAppID] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.appIDs
        }
        return viewModel.appIDs.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText) ||
            $0.identifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section(header: Text("已注册应用 ID (\(viewModel.appIDs.count))")) {
                if filteredAppIDs.isEmpty {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text(searchText.isEmpty ? "开发者中心暂无已注册的应用 ID。" : "未找到匹配的应用 ID。")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                } else {
                    ForEach(filteredAppIDs, id: \.identifier) { appID in
                        NavigationLink(destination: AppIDDetailView(appID: appID, viewModel: viewModel, presentingViewController: presentingViewController)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(appID.name.isEmpty ? "应用 ID" : appID.name)
                                        .font(.headline)
                                    Spacer()
                                    if !appID.features.isEmpty {
                                        Text("\(appID.features.count) 项能力")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.15))
                                            .foregroundColor(.accentColor)
                                            .cornerRadius(6)
                                    }
                                }
                                Text(appID.bundleIdentifier)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text("ID：\(appID.identifier)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if let expiration = appID.expirationDate {
                                        Text("到期：\(formatDate(expiration))")
                                            .font(.caption)
                                            .foregroundColor(expiration < Date() ? .red : .secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        #if !os(tvOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            SwiftUI.Button(role: .destructive) {
                                appIDToDelete = appID
                                showDeleteConfirmation = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        #endif
                        .contextMenu {
                            SwiftUI.Button(role: .destructive) {
                                appIDToDelete = appID
                                showDeleteConfirmation = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        #if !os(tvOS)
        .listStyle(InsetGroupedListStyle())
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "搜索应用 ID")
        #else
        .listStyle(GroupedListStyle())
        #endif
        .navigationTitle("应用 ID (App IDs)")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SwiftUI.Button {
                    showRegisterSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await viewModel.fetchAppIDs(presentingViewController: presentingViewController, isPullToRefresh: true)
        }
        .sheet(isPresented: $showRegisterSheet) {
            NavigationView {
                Form {
                    Section(header: Text("应用 ID 信息"), footer: Text("Bundle ID 必须采用反向域名格式（例如 com.example.myapp）。")) {
                        TextField("名称（例如 My App）", text: $newAppIDName)
                        TextField("Bundle ID 包名", text: $newAppIDBundleID)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .navigationTitle("注册新应用 ID")
                .navigationBarItems(
                    leading: SwiftUI.Button("取消") {
                        newAppIDName = ""
                        newAppIDBundleID = ""
                        showRegisterSheet = false
                    },
                    trailing: SwiftUI.Button("注册") {
                        let name = newAppIDName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let bundleID = newAppIDBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty, !bundleID.isEmpty else { return }
                        Task {
                            let success = await viewModel.createAppID(name: name, bundleIdentifier: bundleID, presentingViewController: presentingViewController)
                            if success {
                                newAppIDName = ""
                                newAppIDBundleID = ""
                                showRegisterSheet = false
                            }
                        }
                    }
                    .disabled(newAppIDName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              newAppIDBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              viewModel.isActionLoading)
                )
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text(viewModel.isPaidAccount ? "删除应用 ID？" : "警告：确定删除应用 ID？"),
                message: Text(deleteAlertMessage),
                primaryButton: .destructive(Text("删除")) {
                    if let target = appIDToDelete {
                        Task {
                            _ = await viewModel.deleteAppID(target, presentingViewController: presentingViewController)
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .developerServicesToast(viewModel: viewModel)
    }

    private var deleteAlertMessage: String {
        guard let appID = appIDToDelete else { return "" }
        let name = appID.name.isEmpty ? "该应用 ID" : "「\(appID.name)」"
        let bundleID = appID.bundleIdentifier.isEmpty ? "" : " (\(appID.bundleIdentifier))"

        if viewModel.isPaidAccount {
            return "确定要删除 \(name)\(bundleID) 吗？关联的描述文件也将一并移除。"
        }

        var expiryNotice = "直至其原有的 7 天有效期自然到期后才会释放。"
        if let expiration = appID.expirationDate {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: Date(), to: expiration)
            if let days = components.day, days > 0 {
                expiryNotice = "直至 \(days) 天后（原 7 天周期结束）才会自动过期释放\(days == 1 ? "" : "")。"
            }
        }

        return "警告：免费账号删除 \(name)\(bundleID) 并不会立即释放每周 10 个的应用 ID 配额！\n\n删除后该标识符将进入冻结保留状态且无法继续使用，\(expiryNotice)\n\n确定仍要删除吗？"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
