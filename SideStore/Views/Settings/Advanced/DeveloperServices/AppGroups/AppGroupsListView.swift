//
//  AppGroupsListView.swift
//  SideStore
//
//  Created by Magesh K on 2/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct AppGroupsListView: View {
    @ObservedObject var viewModel: DeveloperServicesViewModel
    weak var presentingViewController: UIViewController?

    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var newGroupName = ""
    @State private var newGroupIdentifier = "group."

    @State private var groupToEdit: ALTAppGroup? = nil
    @State private var editGroupName = ""
    @State private var showSheetDeleteConfirmation = false

    @State private var groupToDelete: ALTAppGroup? = nil
    @State private var showDeleteConfirmation = false

    private var filteredGroups: [ALTAppGroup] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.appGroups
        }
        return viewModel.appGroups.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.groupIdentifier.localizedCaseInsensitiveContains(searchText) ||
            $0.identifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section(header: Text("应用组 (\(viewModel.appGroups.count))"), footer: Text("应用组允许同一开发者团队名下的多个应用与扩展之间共享数据容器。轻点条目可修改描述或删除。")) {
                if filteredGroups.isEmpty {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text(searchText.isEmpty ? "开发者中心暂无应用组。" : "未找到匹配的应用组。")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                } else {
                    ForEach(filteredGroups, id: \.identifier) { group in
                        SwiftUI.Button {
                            editGroupName = group.name
                            groupToEdit = group
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(group.name.isEmpty ? "应用组" : group.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(group.groupIdentifier)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text("组 ID：\(group.identifier)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        #if !os(tvOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            SwiftUI.Button(role: .destructive) {
                                groupToDelete = group
                                showDeleteConfirmation = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }

                            SwiftUI.Button {
                                editGroupName = group.name
                                groupToEdit = group
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        #endif
                        .contextMenu {
                            SwiftUI.Button {
                                editGroupName = group.name
                                groupToEdit = group
                            } label: {
                                Label("修改名称", systemImage: "pencil")
                            }
                            #if !os(tvOS)
                            SwiftUI.Button {
                                UIPasteboard.general.string = group.groupIdentifier
                            } label: {
                                Label("复制标识符", systemImage: "doc.on.doc")
                            }
                            #endif
                            SwiftUI.Button(role: .destructive) {
                                groupToDelete = group
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
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "搜索应用组")
        #else
        .listStyle(GroupedListStyle())
        #endif
        .navigationTitle("应用组 (App Groups)")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SwiftUI.Button {
                    newGroupName = ""
                    newGroupIdentifier = "group."
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await viewModel.fetchAppGroups(presentingViewController: presentingViewController, isPullToRefresh: true)
        }
        .sheet(isPresented: $showCreateSheet) {
            NavigationView {
                Form {
                    Section(header: Text("应用组信息"), footer: Text("应用组标识符必须以 'group.' 开头（例如 group.com.example.shared）。")) {
                        TextField("名称（例如 Shared Storage）", text: $newGroupName)
                        TextField("应用组标识符", text: $newGroupIdentifier)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .navigationTitle("新建应用组")
                .navigationBarItems(
                    leading: SwiftUI.Button("取消") {
                        showCreateSheet = false
                    },
                    trailing: SwiftUI.Button("创建") {
                        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let groupID = newGroupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty, !groupID.isEmpty else { return }
                        Task {
                            let success = await viewModel.createAppGroup(name: name, groupIdentifier: groupID, presentingViewController: presentingViewController)
                            if success {
                                showCreateSheet = false
                            }
                        }
                    }
                    .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              newGroupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              !newGroupIdentifier.hasPrefix("group.") ||
                              viewModel.isActionLoading)
                )
            }
        }
        .sheet(item: $groupToEdit) { group in
            NavigationView {
                Form {
                    Section(header: Text("描述名称"), footer: Text("描述名称中不可包含 @、&、*、'、\"、-、. 等特殊字符。")) {
                        TextField("描述名称", text: $editGroupName)
                    }

                    Section(header: Text("标识符")) {
                        Text(group.groupIdentifier)
                            .foregroundColor(.secondary)
                    }

                    Section {
                        SwiftUI.Button(role: .destructive) {
                            showSheetDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("删除此应用组")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("编辑应用组配置")
                .navigationBarItems(
                    leading: SwiftUI.Button("取消") {
                        groupToEdit = nil
                    },
                    trailing: SwiftUI.Button("保存") {
                        let trimmed = editGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        Task {
                            let success = await viewModel.updateAppGroup(group, newName: trimmed, presentingViewController: presentingViewController)
                            if success {
                                groupToEdit = nil
                            }
                        }
                    }
                    .disabled(editGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              editGroupName == group.name ||
                              viewModel.isActionLoading)
                )
                .alert(isPresented: $showSheetDeleteConfirmation) {
                    Alert(
                        title: Text("删除应用组？"),
                        message: Text("确定要从 Apple 开发者中心删除应用组「\(group.name)」(\(group.groupIdentifier)) 吗？"),
                        primaryButton: .destructive(Text("删除")) {
                            Task {
                                let success = await viewModel.deleteAppGroup(group, presentingViewController: presentingViewController)
                                if success {
                                    groupToEdit = nil
                                }
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("删除应用组？"),
                message: Text("确定要从 Apple 开发者中心删除应用组「\(groupToDelete?.name ?? "该应用组")」(\(groupToDelete?.groupIdentifier ?? "")) 吗？"),
                primaryButton: .destructive(Text("删除")) {
                    if let target = groupToDelete {
                        Task {
                            _ = await viewModel.deleteAppGroup(target, presentingViewController: presentingViewController)
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .developerServicesToast(viewModel: viewModel)
    }
}
