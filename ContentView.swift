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

    private var appGridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(64), spacing: 10, alignment: .top), count: 4)
    }

    private var appGridHeight: CGFloat {
        let rowCount = max(1, (shortcuts.count + 3) / 4)
        return min(CGFloat(rowCount) * 96 + 20, 350)
    }

    private var panelCornerRadius: CGFloat { 24 }
    
    @State private var isLaunchAtLoginEnabled: Bool = SMAppService.mainApp.status == .enabled
    @State private var draggingShortcut: ShortcutApp?
    @State private var orderedShortcuts: [ShortcutApp] = []

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
                            AppIconView(shortcut: shortcut)
                                .opacity(draggingShortcut?.id == shortcut.id ? 0.45 : 1)
                                .zIndex(draggingShortcut?.id == shortcut.id ? 1 : 0)
                                .onDrag {
                                    draggingShortcut = shortcut
                                    return NSItemProvider(object: shortcut.id.uuidString as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: AppReorderDropDelegate(
                                        targetShortcut: shortcut,
                                        orderedShortcuts: $orderedShortcuts,
                                        draggingShortcut: $draggingShortcut,
                                        modelContext: modelContext
                                    )
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
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
}

struct AppReorderDropDelegate: DropDelegate {
    let targetShortcut: ShortcutApp
    @Binding var orderedShortcuts: [ShortcutApp]
    @Binding var draggingShortcut: ShortcutApp?
    let modelContext: ModelContext

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        guard
            let draggingShortcut,
            draggingShortcut.id != targetShortcut.id,
            let fromIndex = orderedShortcuts.firstIndex(where: { $0.id == draggingShortcut.id }),
            let toIndex = orderedShortcuts.firstIndex(where: { $0.id == targetShortcut.id })
        else {
            return
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            let movedShortcut = orderedShortcuts.remove(at: fromIndex)
            orderedShortcuts.insert(movedShortcut, at: toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        saveOrder()
        draggingShortcut = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
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
}

struct AppIconView: View {
    let shortcut: ShortcutApp
    @Environment(\.modelContext) private var modelContext
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
                
                if isHovering {
                    Button(action: {
                        withAnimation(.spring()) {
                            modelContext.delete(shortcut)
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
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
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            // Subtle click animation
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
