//
//  ContentView.swift
//  MenuDock
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ServiceManagement
import Combine
import AppKit
import ApplicationServices

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: [
        SortDescriptor(\ShortcutApp.sortIndex),
        SortDescriptor(\ShortcutApp.name)
    ]) private var shortcuts: [ShortcutApp]
    @Environment(\.colorScheme) private var colorScheme

    private let appGridColumnCount = 4
    private let appGridCellWidth: CGFloat = 64
    private let appGridCellHeight: CGFloat = 82
    private let appGridColumnSpacing: CGFloat = 10
    private let appGridRowSpacing: CGFloat = 14
    private let appGridHorizontalPadding: CGFloat = 16
    private let appGridVerticalPadding: CGFloat = 18

    private var appGridColumns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(appGridCellWidth), spacing: appGridColumnSpacing, alignment: .top),
            count: appGridColumnCount
        )
    }

    private var appGridHeight: CGFloat {
        let rowCount = max(1, (displayedShortcuts.count + appGridColumnCount - 1) / appGridColumnCount)
        let contentHeight = CGFloat(rowCount) * appGridCellHeight + CGFloat(max(0, rowCount - 1)) * appGridRowSpacing
        return min(contentHeight + appGridVerticalPadding * 2, 350)
    }

    private var panelCornerRadius: CGFloat { 24 }
    
    @State private var isLaunchAtLoginEnabled: Bool = SMAppService.mainApp.status == .enabled
    @State private var draggingShortcut: ShortcutApp?
    @State private var orderedShortcuts: [ShortcutApp] = []
    @State private var isDeleteMode = false
    @AppStorage("liquidTheme") private var liquidTheme: String = "system"
    @ObservedObject private var hotkeyManager = GlobalHotkeyManager.shared

    private var displayedShortcuts: [ShortcutApp] {
        orderedShortcuts.isEmpty ? shortcuts : orderedShortcuts
    }
    
    private var activeColorScheme: ColorScheme {
        if liquidTheme == "light" { return .light }
        if liquidTheme == "dark" { return .dark }
        return colorScheme
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { isLaunchAtLoginEnabled },
            set: { newValue in
                isLaunchAtLoginEnabled = newValue
                do {
                    if newValue {
                        if SMAppService.mainApp.status != .enabled {
                            try SMAppService.mainApp.register()
                        }
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Failed to toggle launch at login: \(error)")
                    isLaunchAtLoginEnabled = !newValue
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text("MenuDock")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Actions Group
                ControlGroup {
                    Button {
                        addApp()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 24, height: 26)
                    }
                    .help("アプリを追加")
                    
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                            isDeleteMode.toggle()
                        }
                    } label: {
                        Image(systemName: isDeleteMode ? "checkmark" : "minus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 24, height: 26)
                    }
                    .disabled(displayedShortcuts.isEmpty)
                    .help(isDeleteMode ? "削除モードを完了" : "アプリを削除")
                }
                .controlSize(.small)
                .tint(isDeleteMode ? .blue : .secondary)
                
                // Settings Menu
                Menu {
                    Picker(selection: $liquidTheme) {
                        Text("システム設定に従う").tag("system")
                        Text("ダーク (ディープ)").tag("dark")
                        Text("ライト (パステル)").tag("light")
                    } label: {
                        Label("テーマ設定", systemImage: "paintpalette")
                    }
                    .pickerStyle(.menu)
                    Button {
                        openWindow(id: "about")
                    } label: {
                        Label("設定と使い方", systemImage: "gearshape.fill")
                    }
                    Divider()
                    Toggle("ログイン時に自動起動", isOn: launchAtLoginBinding)
                    Divider()
                    Button(role: .destructive) {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("終了", systemImage: "power")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 30, height: 28)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .controlSize(.small)
                .tint(.secondary)
                .help("設定")
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, displayedShortcuts.isEmpty ? 12 : 8)
            
            // Content
            if displayedShortcuts.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(activeColorScheme == .dark ? 0.1 : 0.2))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "plus.square.dashed")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(spacing: 6) {
                        Text("ショートカットがありません")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                        Text("お気に入りのアプリを追加して、\nすばやくアクセスしましょう。")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    
                    Button(action: addApp) {
                        Label("アプリを追加する", systemImage: "plus")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 12))
                    .controlSize(.regular)
                }
                .padding(.horizontal, 28)
                .padding(.top, 18)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                ScrollView {
                    LazyVGrid(columns: appGridColumns, alignment: .center, spacing: 14) {
                        ForEach(displayedShortcuts) { shortcut in
                            AppIconView(
                                shortcut: shortcut,
                                isDeleteMode: isDeleteMode,
                                onDelete: {
                                    deleteShortcut(shortcut)
                                }
                            )
                                .opacity(draggingShortcut?.id == shortcut.id ? 0.45 : 1)
                                .zIndex(draggingShortcut?.id == shortcut.id ? 1 : 0)
                                .highPriorityGesture(
                                    DragGesture(minimumDistance: 8, coordinateSpace: .named("appGrid"))
                                        .onChanged { value in
                                            guard !isDeleteMode else { return }
                                            handleDragChanged(value, shortcut: shortcut)
                                        }
                                        .onEnded { _ in
                                            guard !isDeleteMode else { return }
                                            handleDragEnded()
                                        }
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .coordinateSpace(name: "appGrid")
                    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: displayedShortcuts.map(\.id))
                }
                .frame(height: appGridHeight)
                .scrollDisabled(appGridHeight < 350)
            }
        }
        .frame(width: 320)
        .environment(\.colorScheme, activeColorScheme)
        .background(WindowBackgroundConfigurator())
        .onAppear {
            isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            syncDisplayedShortcuts()
            normalizeShortcutOrderIfNeeded()
        }
        .onChange(of: shortcuts.map(\.id)) { _, _ in
            guard draggingShortcut == nil else { return }
            syncDisplayedShortcuts()
            if shortcuts.isEmpty {
                isDeleteMode = false
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { AppDelegate.shared?.updatePanelSize(proxy.size) }
                    .onChange(of: proxy.size) { newSize in
                        AppDelegate.shared?.updatePanelSize(newSize)
                    }
            }
            ZStack {
                // 1. Base Real-time Environmental Refraction (Simulated with saturation boost)
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                    .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
                    .saturation(1.5) // Saturation boost for Liquid Glass

                // 2. Adaptive physics-based meta-substance (Fluid motion)
                LiquidBlobBackground(isLightMode: activeColorScheme == .light)
                    .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
                    .opacity(activeColorScheme == .light ? 0.85 : 0.8)
                    .blendMode(activeColorScheme == .light ? .normal : .plusLighter)

                // 3. Thick Glass Frosting with Depth
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(activeColorScheme == .dark ? 0.85 : 0.65)
                    .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))

                // 4. Inner Bevel & Refraction (Thickness)
                RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(activeColorScheme == .dark ? 0.6 : 0.1),
                                Color.clear,
                                Color.white.opacity(activeColorScheme == .dark ? 0.2 : 0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )

                // 5. Specular Highlights (Surface Reflection)
                RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(activeColorScheme == .dark ? 0.9 : 0.95),
                                Color.white.opacity(activeColorScheme == .dark ? 0.1 : 0.2),
                                Color.white.opacity(activeColorScheme == .dark ? 0.3 : 0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .environment(\.colorScheme, activeColorScheme)
            .shadow(color: .black.opacity(activeColorScheme == .dark ? 0.5 : 0.2), radius: 24, x: 0, y: 12)
            .ignoresSafeArea()
        }
    }

    private func addApp() {
        // Run asynchronously so the menu can close without freezing
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.application]
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.prompt = "追加"
            
            if panel.runModal() == .OK {
                var existingPaths = Set(shortcuts.map(\.path))
                var nextSortIndex = (shortcuts.map(\.sortIndex).max() ?? -1) + 1
                
                for url in panel.urls {
                    let path = url.path
                    
                    if !existingPaths.contains(path) {
                        let name = url.deletingPathExtension().lastPathComponent
                        let newShortcut = ShortcutApp(name: name, path: path, sortIndex: nextSortIndex)
                        modelContext.insert(newShortcut)
                        existingPaths.insert(path)
                        nextSortIndex += 1
                    }
                }
                
                do {
                    try modelContext.save()
                } catch {
                    print("Failed to save SwiftData context: \(error)")
                }
            }
        }
    }

    private func deleteShortcut(_ shortcut: ShortcutApp) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
            orderedShortcuts.removeAll { $0.id == shortcut.id }
            modelContext.delete(shortcut)
        }

        saveOrder()

        if orderedShortcuts.isEmpty {
            isDeleteMode = false
        }
    }

    private func normalizeShortcutOrderIfNeeded() {
        let orderedShortcuts = shortcuts.enumerated()
        let needsNormalization = orderedShortcuts.contains { index, shortcut in
            shortcut.sortIndex != index
        }

        guard needsNormalization else { return }

        for (index, shortcut) in orderedShortcuts {
            shortcut.sortIndex = index
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to normalize shortcut order: \(error)")
        }
    }

    private func syncDisplayedShortcuts() {
        orderedShortcuts = shortcuts
    }

    private func handleDragChanged(_ value: DragGesture.Value, shortcut: ShortcutApp) {
        if draggingShortcut == nil {
            draggingShortcut = shortcut
        }

        guard
            let draggingShortcut,
            let fromIndex = orderedShortcuts.firstIndex(where: { $0.id == draggingShortcut.id })
        else {
            return
        }

        let toIndex = insertionIndex(for: value.location)
        guard fromIndex != toIndex else { return }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            let movedShortcut = orderedShortcuts.remove(at: fromIndex)
            orderedShortcuts.insert(movedShortcut, at: toIndex)
        }
    }

    private func handleDragEnded() {
        saveOrder()
        draggingShortcut = nil
    }

    private func saveOrder() {
        for (index, shortcut) in orderedShortcuts.enumerated() {
            shortcut.sortIndex = index
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save shortcut order: \(error)")
        }
    }

    private func insertionIndex(for location: CGPoint) -> Int {
        guard !orderedShortcuts.isEmpty else { return 0 }

        let columnPitch = appGridCellWidth + appGridColumnSpacing
        let rowPitch = appGridCellHeight + appGridRowSpacing
        let x = max(0, location.x - appGridHorizontalPadding)
        let y = max(0, location.y - appGridVerticalPadding)

        let column = min(
            appGridColumnCount - 1,
            max(0, Int((x / columnPitch).rounded(.toNearestOrAwayFromZero)))
        )
        let row = max(0, Int((y / rowPitch).rounded(.toNearestOrAwayFromZero)))
        let index = row * appGridColumnCount + column

        return min(max(0, index), orderedShortcuts.count - 1)
    }
}

struct AppIconView: View {
    let shortcut: ShortcutApp
    let isDeleteMode: Bool
    let onDelete: () -> Void
    @State private var icon: NSImage?
    @State private var isHovering = false
    @State private var isPressed = false
    @State private var jigglePhase: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                if let icon = icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.2))
                        .frame(width: 48, height: 48)
                        .overlay(Image(systemName: "app").foregroundStyle(.secondary))
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                
                if isDeleteMode {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white, .red)
                            .shadow(radius: 2)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: -6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            Text(shortcut.name)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(isHovering ? .primary : .secondary)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 3)
        .frame(width: 64, height: 82, alignment: .top)
        .background(
            ZStack {
                if isHovering {
                    // Base Liquid Glass for App Icon
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(colorScheme == .dark ? 0.6 : 0.5)
                    
                    // Inner refraction
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.25 : 0.4),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.overlay)
                    
                    // Specular Highlight (Stronger on hover)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.9 : 0.95),
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(colorScheme == .dark ? 0.3 : 0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                    
                    // Subtle colored glow behind the app icon to blend with the Liquid background
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.2))
                        .blur(radius: 10)
                }
            }
            .shadow(color: isHovering ? .black.opacity(0.25) : .clear, radius: isHovering ? 10 : 0, x: 0, y: isHovering ? 5 : 0)
        )
        .scaleEffect(isPressed ? 0.94 : (isHovering ? 1.03 : 1.0))
        .rotationEffect(.degrees(isDeleteMode ? (jigglePhase ? -2.5 : 2.5) : 0))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: isDeleteMode)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onChange(of: isDeleteMode) { _, newValue in
            updateJiggleAnimation(isActive: newValue)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .modifier(AppLaunchGestureModifier(isEnabled: !isDeleteMode) { openingNewWindow in
            handleLaunchTap(openingNewWindow: openingNewWindow)
        })
        .onAppear {
            loadIcon()
            updateJiggleAnimation(isActive: isDeleteMode)
        }
    }
    
    private func loadIcon() {
        DispatchQueue.global(qos: .userInitiated).async {
            let img = NSWorkspace.shared.icon(forFile: shortcut.path)
            DispatchQueue.main.async {
                self.icon = img
            }
        }
    }

    private func updateJiggleAnimation(isActive: Bool) {
        if isActive {
            jigglePhase = false
            let delay = Double.random(in: 0...0.1)
            withAnimation(.easeInOut(duration: 0.13).repeatForever(autoreverses: true).delay(delay)) {
                jigglePhase = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.12)) {
                jigglePhase = false
            }
        }
    }
    
    private func handleLaunchTap(openingNewWindow: Bool) {
        guard !isDeleteMode else { return }
        isPressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isPressed = false
            launchApp(openingNewWindow: openingNewWindow)
        }
    }

    private func launchApp(openingNewWindow: Bool = false) {
        let url = URL(fileURLWithPath: shortcut.path)
        if openingNewWindow {
            openNewWindow(for: url)
        } else {
            NSWorkspace.shared.open(url)
        }
        AppDelegate.shared?.panel.orderOut(nil)
    }

    private func openNewWindow(for url: URL) {
        if let runningApp = runningApplication(for: url) {
            runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            pressNewWindowMenuItem(to: runningApp)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
            if let error {
                print("Failed to launch application: \(error)")
                return
            }

            guard let app else { return }
            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
    }

    private func runningApplication(for url: URL) -> NSRunningApplication? {
        if
            let bundleIdentifier = Bundle(url: url)?.bundleIdentifier,
            let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        {
            return app
        }

        return NSWorkspace.shared.runningApplications.first { app in
            app.bundleURL?.standardizedFileURL == url.standardizedFileURL
        }
    }

    private func pressNewWindowMenuItem(to app: NSRunningApplication) {
        guard isAccessibilityTrusted() else {
            print("Accessibility permission is required to open a new window in another app.")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if !pressMatchingNewWindowMenuItem(in: app) {
                print("No New Window menu item was found for \(app.localizedName ?? "the selected app").")
            }
        }
    }

    private func pressMatchingNewWindowMenuItem(in app: NSRunningApplication) -> Bool {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let menuBarAttribute = axAttribute(kAXMenuBarAttribute, of: appElement) else {
            return false
        }

        let menuBar = menuBarAttribute as! AXUIElement
        return pressMatchingNewWindowMenuItem(in: menuBar, depth: 0)
    }

    private func pressMatchingNewWindowMenuItem(in element: AXUIElement, depth: Int) -> Bool {
        guard depth < 6 else { return false }

        if
            let title = axAttribute(kAXTitleAttribute, of: element) as? String,
            isNewWindowMenuTitle(title),
            isAXElementEnabled(element)
        {
            return AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
        }

        for child in axChildren(of: element) {
            if pressMatchingNewWindowMenuItem(in: child, depth: depth + 1) {
                return true
            }
        }

        return false
    }

    private func isNewWindowMenuTitle(_ title: String) -> Bool {
        let normalized = title
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "...", with: "")
            .replacingOccurrences(of: "…", with: "")

        let excludedTerms = ["private", "incognito", "プライベート", "シークレット"]
        if excludedTerms.contains(where: normalized.contains) {
            return false
        }

        let exactMatches = [
            "newwindow",
            "新規ウインドウ",
            "新規ウィンドウ",
            "新しいウインドウ",
            "新しいウィンドウ"
        ]
        if exactMatches.contains(normalized) {
            return true
        }

        let hasEnglishNewWindow = normalized.contains("new") && normalized.contains("window")
        let hasJapaneseNewWindow = (normalized.contains("新規") || normalized.contains("新しい"))
            && (normalized.contains("ウインドウ") || normalized.contains("ウィンドウ"))

        return hasEnglishNewWindow || hasJapaneseNewWindow
    }

    private func isAXElementEnabled(_ element: AXUIElement) -> Bool {
        (axAttribute(kAXEnabledAttribute, of: element) as? Bool) ?? true
    }

    private func axChildren(of element: AXUIElement) -> [AXUIElement] {
        (axAttribute(kAXChildrenAttribute, of: element) as? [AXUIElement]) ?? []
    }

    private func axAttribute(_ attribute: String, of element: AXUIElement) -> AnyObject? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value
    }

    private func isAccessibilityTrusted() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }
}

private struct AppLaunchGestureModifier: ViewModifier {
    let isEnabled: Bool
    let onLaunch: (Bool) -> Void

    func body(content: Content) -> some View {
        content.gesture(
            TapGesture(count: 2)
                .onEnded {
                    onLaunch(true)
                }
                .exclusively(before:
                    TapGesture(count: 1)
                        .onEnded {
                            onLaunch(false)
                        }
                ),
            including: isEnabled ? .all : .none
        )
    }
}

// Helper view for macOS native glass blur effect
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.identifier = NSUserInterfaceItemIdentifier("CustomLiquidGlass")
        view.blendingMode = blendingMode
        view.state = .active
        view.material = material
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
        nsView.isEmphasized = false
        nsView.appearance = context.environment.colorScheme == .dark ? NSAppearance(named: .vibrantDark) : NSAppearance(named: .vibrantLight)
    }
}

class ClearBackgroundView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        clearSystemBackground()
    }
    
    override func layout() {
        super.layout()
        clearSystemBackground()
    }
    
    private func clearSystemBackground() {
        guard let window = self.window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        
        if let contentView = window.contentView?.superview {
            hideSystemBackgrounds(in: contentView)
        }
    }
    
    private func hideSystemBackgrounds(in view: NSView) {
        if let vev = view as? NSVisualEffectView, vev.identifier?.rawValue != "CustomLiquidGlass" {
            vev.isHidden = true
            vev.alphaValue = 0
            vev.state = .inactive
        }
        for subview in view.subviews {
            hideSystemBackgrounds(in: subview)
        }
    }
}

struct WindowBackgroundConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        return ClearBackgroundView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let clearView = nsView as? ClearBackgroundView {
            clearView.needsLayout = true
        }
    }
}

struct LiquidBlobBackground: View {
    @State private var animate = false
    var isLightMode: Bool
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Blob 1
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: isLightMode 
                                ? [Color.pink.opacity(0.4), Color.blue.opacity(0.3)]
                                : [Color.purple.opacity(0.8), Color.indigo.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: proxy.size.width * 1.2, height: proxy.size.width * 1.2)
                    .blur(radius: 60)
                    .offset(x: animate ? -proxy.size.width * 0.1 : proxy.size.width * 0.3,
                            y: animate ? -proxy.size.height * 0.1 : proxy.size.height * 0.4)
                
                // Blob 2
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: isLightMode 
                                ? [Color.cyan.opacity(0.4), Color.mint.opacity(0.5)]
                                : [Color.cyan.opacity(0.7), Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: proxy.size.width * 1.3, height: proxy.size.width * 1.3)
                    .blur(radius: 70)
                    .offset(x: animate ? proxy.size.width * 0.4 : -proxy.size.width * 0.2,
                            y: animate ? proxy.size.height * 0.4 : -proxy.size.height * 0.1)
                
                // Blob 3
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: isLightMode 
                                ? [Color.purple.opacity(0.3), Color.pink.opacity(0.4)]
                                : [Color.pink.opacity(0.6), Color.orange.opacity(0.5)],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )
                    .frame(width: proxy.size.width, height: proxy.size.width)
                    .blur(radius: 50)
                    .offset(x: animate ? proxy.size.width * 0.1 : proxy.size.width * 0.6,
                            y: animate ? -proxy.size.height * 0.3 : proxy.size.height * 0.3)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

        if let build, !build.isEmpty {
            return "バージョン \(version) (\(build))"
        }

        return "バージョン \(version)"
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // App Icon & Name
            VStack(spacing: 12) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                
                VStack(spacing: 4) {
                    Text("MenuDock")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(versionText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 16)
            
            // Description
            Text("メニューバーからお気に入りのアプリに瞬時にアクセスできる、ランチャーアプリです。")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            // Shortcuts
            VStack(alignment: .leading, spacing: 16) {
                Text("ショートカット設定")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .padding(.bottom, -4)
                
                HStack {
                    Text("MenuDockを呼び出す:")
                        .font(.system(size: 13))
                    Spacer()
                    ShortcutRecorder()
                }
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            
            // Usage
            VStack(alignment: .leading, spacing: 16) {
                Text("使い方")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .padding(.bottom, -4)
                
                UsageRow(icon: "plus.app", title: "アプリの追加", desc: "メニューの「アプリを追加...」からお好きなアプリを登録できます。")
                UsageRow(icon: "cursorarrow.click.2", title: "アプリを開く", desc: "アイコンをクリックで通常起動、ダブルクリックでアプリの新規ウインドウメニューを実行します。起動済みアプリで使う場合はアクセシビリティ許可が必要です。")
                UsageRow(icon: "hand.draw", title: "並び替え", desc: "アイコンをドラッグ＆ドロップして、好きな順番に並び替えられます。")
                UsageRow(icon: "minus.circle", title: "アプリの削除", desc: "メニューの「削除モード」をオンにして、アイコン右上の×ボタンで外せます。")
                UsageRow(icon: "paintpalette", title: "テーマの変更", desc: "設定メニューから好みのLiquid Glassテーマ（ダーク/ライト）に切り替えられます。")
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            
            Button("閉じる") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.bottom, 20)
        }
        .frame(width: 420)
        .fixedSize()
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
    }
}

struct UsageRow: View {
    let icon: String
    let title: String
    let desc: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.tint)
                .frame(width: 24, alignment: .center)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ShortcutRecorder: View {
    @ObservedObject var manager = GlobalHotkeyManager.shared
    @State private var isRecording = false
    @State private var localMonitor: Any?
    
    var body: some View {
        Button {
            isRecording = true
            startRecording()
        } label: {
            Text(isRecording ? "キーを入力..." : manager.shortcutString)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .frame(minWidth: 100)
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(isRecording ? .blue : Color.secondary.opacity(0.3))
        .foregroundStyle(isRecording ? .white : .primary)
        .onChange(of: isRecording) { recording in
            if !recording { stopRecording() }
        }
        .onDisappear {
            stopRecording()
        }
    }
    
    private func startRecording() {
        stopRecording()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Esc cancels
            if event.keyCode == 53 {
                isRecording = false
                stopRecording()
                return nil
            }
            manager.setCustomHotkey(keyCode: event.keyCode, cocoaModifiers: event.modifierFlags)
            isRecording = false
            stopRecording()
            return nil
        }
    }
    
    private func stopRecording() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ShortcutApp.self, inMemory: true)
}
