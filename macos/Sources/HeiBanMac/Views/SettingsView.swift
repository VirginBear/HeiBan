import AppKit
import HeiBanCore
import SwiftUI

public class SettingsViewModel: ObservableObject {
    @Published public var selectedTab: Int = 0
    @Published public var settings: AppSettings = AppSettingsManager.shared.current
    @Published public var syncState: CloudSyncState = AppSettingsManager.shared.syncState
    @Published public var showingResetAlert: Bool = false

    public init() {}

    public func refresh() {
        settings = AppSettingsManager.shared.current
        syncState = AppSettingsManager.shared.syncState
    }
}

public struct NativeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = SettingsViewModel()

    private let sage = Color(red: 0.24, green: 0.43, blue: 0.35)

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header / Tabs
            HStack(spacing: 16) {
                tabButton(title: "一般設定", icon: "gearshape", tag: 0)
                tabButton(title: "畫布預設", icon: "square.dashed", tag: 1)
                tabButton(title: "帳號與雲端", icon: "icloud", tag: 2)
                tabButton(title: "關於黑板", icon: "info.circle", tag: 3)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch vm.selectedTab {
                    case 0:
                        generalSettingsView
                    case 1:
                        canvasSettingsView
                    case 2:
                        cloudAccountView
                    case 3:
                        aboutView
                    default:
                        EmptyView()
                    }
                }
                .padding(24)
            }
            .frame(maxHeight: 460)

            Divider()

            // Footer
            HStack {
                Button("恢復預設值") {
                    vm.showingResetAlert = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button("完成") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(sage)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 580, height: 540)
        .alert("恢復所有設定為預設值？", isPresented: $vm.showingResetAlert) {
            Button("取消", role: .cancel) {}
            Button("恢復預設", role: .destructive) {
                AppSettingsManager.shared.resetToDefaults()
                vm.refresh()
            }
        } message: {
            Text("這會將外觀主題、自動存檔時間、預設字體與工具列設定重設為原廠狀態。")
        }
    }

    private func tabButton(title: String, icon: String, tag: Int) -> some View {
        Button {
            vm.selectedTab = tag
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 13, weight: vm.selectedTab == tag ? .semibold : .regular))
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(vm.selectedTab == tag ? sage.opacity(0.15) : Color.clear)
            .foregroundStyle(vm.selectedTab == tag ? sage : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var generalSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("外觀與主題").font(.headline)
            Picker("應用程式主題", selection: $vm.settings.appTheme) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.settings.appTheme) { _, newTheme in
                AppSettingsManager.shared.update { $0.appTheme = newTheme }
            }

            Divider()

            Text("存檔與安全").font(.headline)
            Picker("本機自動存檔頻率", selection: $vm.settings.autoSaveFrequency) {
                ForEach(AutoSaveFrequency.allCases, id: \.self) { freq in
                    Text(freq.displayName).tag(freq)
                }
            }
            .onChange(of: vm.settings.autoSaveFrequency) { _, newFreq in
                AppSettingsManager.shared.update { $0.autoSaveFrequency = newFreq }
            }
            Text("黑板採用原子替換（Atomic Write）機制保存至專屬沙盒，防止電源中斷導致檔案毀損。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("工具列預設停靠").font(.headline)
            Picker("預設停靠位置", selection: $vm.settings.defaultToolbarDock) {
                Text("左側").tag("left")
                Text("底部").tag("bottom")
                Text("右側").tag("right")
                Text("頂部").tag("top")
                Text("自由浮動").tag("floating")
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.settings.defaultToolbarDock) { _, newDock in
                AppSettingsManager.shared.update { $0.defaultToolbarDock = newDock }
            }

            Toggle("啟用觸控板震動回饋與手柄吸附提醒", isOn: $vm.settings.isHapticFeedbackEnabled)
                .onChange(of: vm.settings.isHapticFeedbackEnabled) { _, val in
                    AppSettingsManager.shared.update { $0.isHapticFeedbackEnabled = val }
                }
        }
    }

    @ViewBuilder
    private var canvasSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新黑板預設模式").font(.headline)
            Picker("畫布型態", selection: $vm.settings.defaultCanvasMode) {
                Text("無限延伸畫布").tag(CanvasMode.infinite)
                Text("固定比例畫布").tag(CanvasMode.fixed)
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.settings.defaultCanvasMode) { _, newMode in
                AppSettingsManager.shared.update { $0.defaultCanvasMode = newMode }
            }

            if vm.settings.defaultCanvasMode == .fixed {
                Picker("預設紙張規格", selection: $vm.settings.defaultPaperPreset) {
                    Text("A4 直式 (210 x 297 mm)").tag("A4")
                    Text("A3 橫式 (420 x 297 mm)").tag("A3")
                    Text("16:9 簡報 (1920 x 1080)").tag("16:9")
                    Text("4:3 課堂 (1024 x 768)").tag("4:3")
                }
                .onChange(of: vm.settings.defaultPaperPreset) { _, newPreset in
                    AppSettingsManager.shared.update { $0.defaultPaperPreset = newPreset }
                }
            }

            Toggle("顯示背景微點方格參考線", isOn: $vm.settings.showCanvasGrid)
                .onChange(of: vm.settings.showCanvasGrid) { _, val in
                    AppSettingsManager.shared.update { $0.showCanvasGrid = val }
                }

            Divider()

            Text("文字預設樣式").font(.headline)
            HStack {
                TextField("預設字體名稱", text: $vm.settings.defaultFontFamily)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: vm.settings.defaultFontFamily) { _, newFont in
                        AppSettingsManager.shared.update { $0.defaultFontFamily = newFont }
                    }
                Stepper(
                    "字級：\(Int(vm.settings.defaultFontSize)) pt", value: $vm.settings.defaultFontSize,
                    in: 12...72, step: 2
                )
                .onChange(of: vm.settings.defaultFontSize) { _, newSize in
                    AppSettingsManager.shared.update { $0.defaultFontSize = newSize }
                }
            }
        }
    }

    @ViewBuilder
    private var cloudAccountView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("帳號狀態").font(.headline)

            HStack(spacing: 12) {
                Image(
                    systemName: vm.settings.loggedInUserEmail != nil
                        ? "checkmark.circle.fill" : "internaldrive"
                )
                .font(.title2)
                .foregroundStyle(vm.settings.loggedInUserEmail != nil ? .green : sage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.syncState.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(vm.syncState.statusDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)

            if let email = vm.settings.loggedInUserEmail {
                HStack {
                    Text("已登入帳號：\(email)")
                    Spacer()
                    Button("登出帳號") {
                        AppSettingsManager.shared.logoutUser()
                        vm.refresh()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("雲端同步說明").font(.subheadline.weight(.medium))
                    Text("HeiBan 目前以本機離線安全優先架構運作。所有黑板檔案皆完整保存於您的 Mac 本地磁碟，即使在完全無網路環境下也能順暢寫作與縮放。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // 真正 OAuth／同步尚未接入；不能用示範帳號冒充成功授權。
                    Button("以 Google 帳號登入 (準備中)") {}
                        .buttonStyle(.borderedProminent)
                        .tint(sage)
                        .disabled(true)
                        .help("尚未接入正式 Google 授權與雲端同步，目前作品保存在本機")
                }
            }
        }
    }

    @ViewBuilder
    private var aboutView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                HeiBanLogo().frame(width: 108, height: 60)
                VStack(alignment: .leading, spacing: 2) {
                    Text(AboutInfo.appName).font(.title2.weight(.bold))
                    Text("版本 \(AboutInfo.appVersion) (\(AboutInfo.buildNumber)) · \(AboutInfo.engineVersion)")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(AboutInfo.copyright)
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }

            Divider()

            HStack {
                Button("意見回覆與問題回報") {
                    if let url = URL(string: AboutInfo.feedbackUrl) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)

                Spacer()
            }

            Text("最新更新日誌 (Changelog)").font(.headline)
            ForEach(AboutInfo.changelog) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text("v\(entry.version) · \(entry.releaseDate)").font(.subheadline.weight(.semibold))
                    ForEach(entry.highlights, id: \.self) { item in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").foregroundStyle(sage)
                            Text(item).font(.caption)
                        }
                    }
                }
                .padding(.bottom, 6)
            }
        }
    }
}
