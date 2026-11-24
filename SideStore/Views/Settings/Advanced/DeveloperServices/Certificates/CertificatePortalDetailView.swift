//
//  CertificatePortalDetailView.swift
//  SideStore
//
//  Created by Magesh K on 8/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct CertificatePortalDetailView: View {
    let certificate: ALTX509Certificate
    @ObservedObject var viewModel: DeveloperServicesViewModel
    weak var presentingViewController: UIViewController?
    @Environment(\.presentationMode) var presentationMode

    @State private var showRevokeAlert = false

    private var isExpired: Bool {
        certificate.expiryDate < Date()
    }

    var body: some View {
        List {
            Section(header: Text("证书详情")) {
                InfoRow(label: "名称", value: certificate.name)
                InfoRow(label: "设备序列号", value: certificate.serialNumber)
                if let identifier = certificate.identifier {
                    InfoRow(label: "证书 ID", value: identifier)
                }
                if let certType = certificate.certificateType {
                    InfoRow(label: "证书类型", value: certType)
                }
                if let typeName = certificate.certificateTypeName {
                    InfoRow(label: "类型名称", value: typeName)
                }
                if let managed = certificate.isManaged {
                    InfoRow(label: "托管方式", value: managed ? "是 (Xcode Cloud)" : "No")
                }
                if let platform = certificate.platform {
                    InfoRow(label: "适用平台", value: platform)
                }
                if let machineName = certificate.machineName {
                    InfoRow(label: "机器备注名称", value: machineName)
                }
                if let machineIdentifier = certificate.machineIdentifier {
                    InfoRow(label: "机器标识符", value: machineIdentifier)
                }
                if let createdBy = certificate.requesterFirstName {
                    InfoRow(label: "创建来源", value: createdBy)
                }
                if let email = certificate.requesterEmail {
                    InfoRow(label: "申请邮箱", value: email)
                }
                if let teamName = viewModel.team?.name {
                    InfoRow(label: "团队名称", value: teamName)
                }
                if let teamID = viewModel.team?.identifier {
                    InfoRow(label: "团队标识符", value: teamID)
                }
                InfoRow(label: "创建时间", value: formatDate(certificate.creationDate))
                InfoRow(label: "到期时间", value: formatDate(certificate.expiryDate), valueColor: isExpired ? .red : .primary)
                InfoRow(label: "状态", value: isExpired ? "Expired" : "Active", valueColor: isExpired ? .red : .green)
            }

            Section(footer: Text("吊销证书将使其在 Apple 服务器永久失效，仅绑定该证书的描述文件需重新生成。")) {
                SwiftUI.Button(role: .destructive) {
                    showRevokeAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                        Text("在开发者中心吊销此证书")
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
        .navigationTitle(certificate.name)
        .refreshable {
            await viewModel.fetchCertificates(presentingViewController: presentingViewController, isPullToRefresh: true)
        }
        .alert(isPresented: $showRevokeAlert) {
            Alert(
                title: Text("确定吊销此证书？"),
                message: Text("确定要在 Apple 开发者中心永久吊销「\(certificate.name)」吗？此操作无法撤销。"),
                primaryButton: .destructive(Text("吊销")) {
                    Task {
                        let success = await viewModel.revokeCertificate(certificate, presentingViewController: presentingViewController)
                        if success {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
