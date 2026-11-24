//
//  MachOResourceViewer.swift
//  SideStore
//
//  Created by Magesh K on 3/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign
import CodeSignKit

struct MachOResourceViewer: View {
    let url: URL

    @State private var parser: MachOParser? = nil
    @State private var dumpText: String = ""
    @State private var isLoaded = false
    @State private var showingShareSheet = false

    var body: some View {
        List {
            if let parser = parser {
                Section(header: Text("Mach-O 二进制概览")) {
                    InfoRow(label: "名称", value: url.lastPathComponent)
                    InfoRow(label: "文件路径", value: url.path)
                    InfoRow(label: "文件大小", value: formatSize(url))

                    let archs = parser.architectures()
                    InfoRow(label: "CPU 架构", value: archs.isEmpty ? "Unknown" : archs.joined(separator: ", "))

                    if let platform = parser.platformType() {
                        InfoRow(label: "适用平台", value: platform)
                    }

                    if let minOS = parser.minimumOSVersion() {
                        InfoRow(label: "最低系统版本", value: minOS)
                    }

                    InfoRow(
                        label: "FairPlay 加密壳 (DRM)",
                        value: parser.isEncrypted() ? "Yes" : "No",
                        valueColor: parser.isEncrypted() ? .orange : .green
                    )

                    if let bundleID = parser.bundleIdentifier() {
                        InfoRow(label: "Bundle ID", value: bundleID)
                    }

                    if let teamID = parser.teamID() {
                        InfoRow(label: "团队 ID", value: teamID)
                    }

                    if let entryOff = parser.entryPoint() {
                        InfoRow(label: "入口偏移地址", value: String(format: "0x%llX", entryOff))
                    }

                    let cdHashes = parser.getCDHashes()
                    if !cdHashes.isEmpty {
                        InfoRow(label: "CDHash", value: cdHashes.joined(separator: "\n"))
                    }
                }

                let x509Certs = parser.x509Certificates()
                if !x509Certs.isEmpty {
                    Section(header: Text("签名证书链 (\(x509Certs.count))")) {
                        ForEach(Array(x509Certs.enumerated()), id: \.offset) { index, cert in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cert.name)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("Serial: \(cert.serialNumber)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if cert.expiryDate != Date.distantPast {
                                    Text("到期：\(formatDate(cert.expiryDate))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                if let ent = try? parser.entitlements(), !ent.isEmpty {
                    Section(header: Text("内嵌权利 (Entitlements)")) {
                        NavigationLink(destination: ResourceTextViewer(title: "内嵌权利 (Entitlements)", explicitContent: ent)) {
                            HStack {
                                Image(systemName: "lock.doc.fill")
                                    .foregroundColor(.green)
                                Text("查看内嵌 Entitlements")
                                    .font(.subheadline)
                                Spacer()
                                Text("XML")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                let libs = parser.linkedLibraries()
                if !libs.isEmpty {
                    Section(header: Text("动态链接库 (\(libs.count))")) {
                        ForEach(libs, id: \.self) { lib in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "cpu")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)
                                Text(lib)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                let segs = parser.segments()
                if !segs.isEmpty {
                    Section(header: Text("二进制段 (\(segs.count))")) {
                        ForEach(segs, id: \.name) { seg in
                            HStack {
                                Text(seg.name)
                                    .font(.system(size: 13, design: .monospaced))
                                    .fontWeight(.medium)
                                Spacer()
                                Text("offset: \(String(format: "0x%llX", seg.offset))  size: \(ByteCountFormatter.string(fromByteCount: Int64(seg.size), countStyle: .file))")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section(header: Text("完整分析报告")) {
                    NavigationLink(destination: ResourceTextViewer(title: "Mach-O 分析报告", explicitContent: dumpText)) {
                        HStack {
                            Image(systemName: "doc.plaintext.fill")
                                .foregroundColor(.blue)
                            Text("查看完整 Mach-O 文本报告")
                                .font(.subheadline)
                        }
                    }
                }
            } else if isLoaded {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 44))
                        .foregroundColor(.orange)
                    Text("非有效的 Mach-O 可执行文件")
                        .font(.headline)
                    Text("无法将 \(url.lastPathComponent) 解析为有效的 Mach-O 二进制。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("正在解析 Mach-O 二进制…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        #if !os(tvOS)
        .listStyle(InsetGroupedListStyle())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !dumpText.isEmpty {
                    SwiftUI.Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityViewController(items: [dumpText])
        }
        #else
        .listStyle(GroupedListStyle())
        #endif
        .navigationTitle(url.lastPathComponent)
        .onAppear {
            guard !isLoaded else { return }
            isLoaded = true
            loadMachO()
        }
    }

    private func loadMachO() {
        guard let p = try? MachOParser(url: url) else { return }
        self.parser = p
        self.dumpText = generateDumpText(p)
    }

    private func generateDumpText(_ p: MachOParser) -> String {
        var info = "--- Mach-O Binary Info: \(url.lastPathComponent) ---\n"
        info += "Path: \(url.path)\n"
        info += "Size: \(formatSize(url))\n"
        info += "Architectures: \(p.architectures().joined(separator: ", "))\n"
        if let platform = p.platformType() {
            info += "Platform: \(platform)\n"
        }
        if let minOS = p.minimumOSVersion() {
            info += "Min OS Version: \(minOS)\n"
        }
        info += "Encrypted (DRM): \(p.isEncrypted() ? "是" : "否")\n"
        if let bundleID = p.bundleIdentifier() {
            info += "Bundle ID: \(bundleID)\n"
        }
        if let teamID = p.teamID() {
            info += "Team ID: \(teamID)\n"
        }
        if let entry = p.entryPoint() {
            info += "Entry Point: \(String(format: "0x%llX", entry))\n"
        }
        let cdHashes = p.getCDHashes()
        if !cdHashes.isEmpty {
            info += "CDHashes:\n"
            for hash in cdHashes {
                info += "  \(hash)\n"
            }
        }

        let certs = p.certificates()
        if !certs.isEmpty {
            info += "Certificates (\(certs.count)):\n"
            for (index, cert) in certs.enumerated() {
                let subject = X509Certificate(der: cert)?.name ?? "Certificate \(index + 1) (\(cert.count) bytes)"
                info += "  [\(index)] \(subject)\n"
            }
        }

        let libs = p.linkedLibraries()
        if !libs.isEmpty {
            info += "Linked Libraries (\(libs.count)):\n"
            for lib in libs {
                info += "  - \(lib)\n"
            }
        }

        let segs = p.segments()
        if !segs.isEmpty {
            info += "Segments (\(segs.count)):\n"
            for seg in segs {
                info += "  - \(seg.name) (offset: \(String(format: "0x%llX", seg.offset)), size: \(ByteCountFormatter.string(fromByteCount: Int64(seg.size), countStyle: .file)))\n"
            }
        }

        if let ent = try? p.entitlements(), !ent.isEmpty {
            info += "\n--- Embedded Entitlements ---\n"
            info += ent
            info += "\n"
        }

        info += "----------------------------------------"
        return info
    }

    private func formatSize(_ url: URL) -> String {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
