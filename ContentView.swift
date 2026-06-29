//
//  ContentView.swift
//  MenuDock
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ServiceManagement

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
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

    private var displayedShortcuts: [ShortcutApp] {
        orderedShortcuts.isEmpty ? shortcuts : orderedShortcuts
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
            HStack {
                Text("MenuDock")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Menu {
                    Button {
                        addApp()
                    } label: {
                        Label("アプリを追加...", systemImage: "plus.app")
                    }
                    Divider()
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                            isDeleteMode.toggle()
                        }
                    } label: {
                        Label(
                            isDeleteMode ? "削除モードを終了" : "削除モード",
                            systemImage: isDeleteMode ? "checkmark.circle" : "minus.circle"
                        )
                    }
                    .disabled(displayedShortcuts.isEmpty)
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
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .controlSize(.small)
                .tint(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, displayedShortcuts.isEmpty ? 12 : 8)
            
            // Content
            if displayedShortcuts.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.regularMaterial)
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
                    .padding(.top, 4)
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
                    .frame(maxWidth: .infinity)
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
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.42), lineWidth: 1)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.34 : 0.16), radius: 28, x: 0, y: 16)
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
                        .fill(.regularMaterial)
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06) : Color.clear)
                .background {
                    if isHovering {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.regularMaterial)
                    }
                }
        )
        .scaleEffect(isPressed ? 0.94 : (isHovering ? 1.03 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: isDeleteMode)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(count: 2) {
            guard !isDeleteMode else { return }
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                launchApp()
            }
        }
        .onAppear {
            loadIcon()
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
    
    private func launchApp() {
        let url = URL(fileURLWithPath: shortcut.path)
        NSWorkspace.shared.open(url)
    }
}

// Helper view for macOS native glass blur effect
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
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
    }
}

struct WindowBackgroundConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configureWindow(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(from: nsView)
        }
    }

    private func configureWindow(from view: NSView) {
        guard let window = view.window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ShortcutApp.self, inMemory: true)
}
