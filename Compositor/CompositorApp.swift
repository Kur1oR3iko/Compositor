import SwiftUI
import UniformTypeIdentifiers
import Sparkle

@main
struct CompositorApp: App {
    @NSApplicationDelegateAdaptor(CompositorApplicationDelegate.self) private var applicationDelegate
    @AppStorage("navigator.visible") private var showsNavigator = false
    @State private var languageSettings = LanguageSettings.shared
    private var session: EditorSession { applicationDelegate.session }
    var body: some Scene {
        Window("Compositor", id: "editor") {
            ProjectWorkspaceView(applicationDelegate: applicationDelegate).roundedControls().localizedInterface()
        }
            .defaultSize(width: 1180, height: 780)
            // Files opened from Finder or dropped on the Dock icon go to the app delegate, which imports them into
            // the open window. Left to SwiftUI, each one builds a throwaway window and fades the editor out and back.
            .handlesExternalEvents(matching: [])
            // A first launch fills the screen (without going full screen); after that macOS reopens the window at the
            // size it was left.
            .defaultWindowPlacement { _, context in
                WindowPlacement(size: context.defaultDisplay.visibleRect.size)
            }
            // The project's name is already on its tab, so the toolbar doesn't repeat it as a window title.
            .windowToolbarStyle(.unifiedCompact(showsTitle: false))
            .commands {
                CommandGroup(replacing: .undoRedo) {
                    // Dialog text fields keep native text undo; document history
                    // is unavailable while an import or modal edit is active.
                    if session.textDraft != nil || session.levels != nil || session.isProjectBusy || session.showsNewDocument || session.showsImporter || session.renamingLayerID != nil || session.transformEdit?.persistent == true {
                        Button(String(localized: "Undo", bundle: L10n.bundle)) {
                            if NSApp.keyWindow?.firstResponder is NSTextView {
                                NSApp.sendAction(NSSelectorFromString("undo:"), to: nil, from: nil)
                            }
                        }
                            .configuredKeyboardShortcut("z")
                        Button(String(localized: "Redo", bundle: L10n.bundle)) {
                            if NSApp.keyWindow?.firstResponder is NSTextView {
                                NSApp.sendAction(NSSelectorFromString("redo:"), to: nil, from: nil)
                            }
                        }
                            .configuredKeyboardShortcut("z", modifiers: [.command, .shift])
                    } else {
                        Button(session.history.canUndo ? String(localized: "Undo \(session.history.undoName)", bundle: L10n.bundle) : String(localized: "Undo", bundle: L10n.bundle)) { session.undo() }
                            .configuredKeyboardShortcut("z").disabled(!session.canUndo)
                        Button(session.history.canRedo ? String(localized: "Redo \(session.history.redoName)", bundle: L10n.bundle) : String(localized: "Redo", bundle: L10n.bundle)) { session.redo() }
                            .configuredKeyboardShortcut("z", modifiers: [.command, .shift]).disabled(!session.canRedo)
                    }
                }
                CommandGroup(replacing: .newItem) {
                    Button(String(localized: "New Canvas…", bundle: L10n.bundle)) {
                        applicationDelegate.showEditor?()
                        Task { await applicationDelegate.projects.newCanvas() }
                    }.configuredKeyboardShortcut("n")
                        .disabled(!applicationDelegate.projects.canStart)
                    Button(String(localized: "Open Project…", bundle: L10n.bundle)) {
                        applicationDelegate.showEditor?()
                        Task { await applicationDelegate.projects.open() }
                    }
                        .configuredKeyboardShortcut("o").disabled(!applicationDelegate.projects.canStart)
                    Menu(String(localized: "Open Recent", bundle: L10n.bundle)) {
                        ForEach(RecentProjects.shared.urls, id: \.self) { url in
                            Button(url.deletingPathExtension().lastPathComponent) {
                                applicationDelegate.showEditor?()
                                Task { await applicationDelegate.projects.open(url) }
                            }
                        }
                        Divider()
                        Button(String(localized: "Clear Menu", bundle: L10n.bundle)) { RecentProjects.shared.clear() }
                            .disabled(RecentProjects.shared.urls.isEmpty)
                    }
                        .disabled(!applicationDelegate.projects.canStart)
                    Button(String(localized: "Import Images…", bundle: L10n.bundle)) { session.showsImporter = true }
                        .disabled(session.levels != nil || session.showsBusy || session.isImporting || session.showsNewDocument)
                }
                CommandGroup(replacing: .saveItem) {
                    Button(String(localized: "Save", bundle: L10n.bundle)) { Task { await applicationDelegate.projects.save() } }
                        .configuredKeyboardShortcut("s").disabled(session.document == nil || !applicationDelegate.projects.canStart)
                    Button(String(localized: "Save As…", bundle: L10n.bundle)) { Task { await applicationDelegate.projects.save(asNew: true) } }
                        .configuredKeyboardShortcut("s", modifiers: [.command, .shift])
                        .disabled(session.document == nil || !applicationDelegate.projects.canStart)
                    Divider()
                    // Export As on JPEG.
                    Button(String(localized: "Export JPEG…", bundle: L10n.bundle)) { Task { await applicationDelegate.projects.exportAs(start: .jpeg) } }
                        .configuredKeyboardShortcut("s", modifiers: [.command, .option, .shift])
                        .disabled(session.document == nil || !applicationDelegate.projects.canStart)
                    Button(String(localized: "Export PNG…", bundle: L10n.bundle)) { Task { await applicationDelegate.projects.exportPNG() } }
                        .configuredKeyboardShortcut("e", modifiers: [.command, .shift])
                        .disabled(session.document == nil || !applicationDelegate.projects.canStart)
                    // PNG, JPEG or PDF, sized and previewed; ⌥⇧⌘W, as Photoshop's Export As.
                    Button(String(localized: "Export As…", bundle: L10n.bundle)) { Task { await applicationDelegate.projects.exportAs() } }
                        .configuredKeyboardShortcut("w", modifiers: [.command, .option, .shift])
                        .disabled(session.document == nil || !applicationDelegate.projects.canStart)
                    Divider()
                    Button(String(localized: "Close Project", bundle: L10n.bundle)) {
                        if let window = applicationDelegate.projects.window {
                            Task { await applicationDelegate.projects.close(window) }
                        }
                    }.configuredKeyboardShortcut("w").disabled(!applicationDelegate.projects.canStart)
                }
                // Grouped: a commands builder takes at most ten items.
                Group {
                    CommandGroup(after: .appInfo) {
                        Button(String(localized: "Check for Updates…", bundle: L10n.bundle)) { applicationDelegate.updater.checkForUpdates() }
                        Menu {
                            ForEach(AppLanguage.allCases, id: \.self) { option in
                                Toggle(isOn: Binding(get: { languageSettings.language == option }, set: { selected in
                                    guard selected, languageSettings.language != option else { return }
                                    languageSettings.select(option)
                                })) {
                                    Text(verbatim: option.title)
                                }
                            }
                        } label: {
                            Text(String(localized: "Language", bundle: L10n.bundle))
                        }
                    }
                    CommandGroup(after: .toolbar) {
                        Button(String(localized: "Search Commands…", bundle: L10n.bundle)) {
                            CommandPaletteController.shared.toggle(session: session, over: applicationDelegate.projects.window)
                        }
                        .configuredKeyboardShortcut("f", modifiers: [.command])
                        // A plain F, shown as menus show keys; the app hands an F meant for a text field to the field
                        // first (see CompositorApplicationDelegate).
                        Toggle(String(localized: "Toggle Fullscreen", bundle: L10n.bundle), isOn: Binding(get: { session.canvasOnly },
                                                            set: { _ in applicationDelegate.toggleCanvasOnly() }))
                            .keyboardShortcut("f", modifiers: [])
                            .disabled(!session.canToggleCanvasOnly)
                        Divider()
                        // With a dialog's preview open (Export As), these zoom that preview rather than the canvas.
                        Button(String(localized: "Fit Canvas", bundle: L10n.bundle)) {
                            if let preview = session.previewZoom { preview(.fit) } else { session.fit() }
                        }.configuredKeyboardShortcut("0").disabled(session.document == nil)
                        Button(String(localized: "Actual Pixels", bundle: L10n.bundle)) {
                            if let preview = session.previewZoom { preview(.actual) } else { session.zoom(to: 1) }
                        }.configuredKeyboardShortcut("1").disabled(session.document == nil)
                        Button(String(localized: "Zoom In", bundle: L10n.bundle)) {
                            guard !(NSApp.keyWindow?.firstResponder is NSText) else { return }
                            if let preview = session.previewZoom { preview(.zoomIn) } else { session.zoomKeyboard(by: 1) }
                        }
                            .configuredKeyboardShortcut("=").disabled(session.document == nil)
                        Button(String(localized: "Zoom Out", bundle: L10n.bundle)) {
                            guard !(NSApp.keyWindow?.firstResponder is NSText) else { return }
                            if let preview = session.previewZoom { preview(.zoomOut) } else { session.zoomKeyboard(by: -1) }
                        }
                            .configuredKeyboardShortcut("-").disabled(session.document == nil)
                        Toggle(String(localized: "Navigator (300% and above)", bundle: L10n.bundle), isOn: $showsNavigator)
                        Toggle(String(localized: "Pixel Grid (800% and above)", bundle: L10n.bundle), isOn: Binding(get: { session.showsPixelGrid },
                                                                              set: { session.showsPixelGrid = $0 }))
                        Toggle(String(localized: "Show Transform Controls", bundle: L10n.bundle), isOn: Binding(get: { session.showsTransformControls },
                                                                          set: { session.showsTransformControls = $0 }))
                            .configuredKeyboardShortcut("h").disabled(session.tool != .move || session.document == nil)
                        Divider()
                        // Print: the canvas as the chosen CMYK profile will print it, tucked in a submenu as few need it. No
                        // shortcuts (Photoshop's ⌘Y sits by ⌘U and would be hit by mistake); Search Commands finds them.
                        Menu(String(localized: "CMYK", bundle: L10n.bundle)) {
                            Toggle(String(localized: "Proof Colors", bundle: L10n.bundle), isOn: Binding(get: { session.proofsColors }, set: { session.proofsColors = $0 }))
                                .assignableShortcut("CMYK Proof Colors")
                                .disabled(session.document == nil)
                            Toggle(String(localized: "Gamut Warning", bundle: L10n.bundle), isOn: Binding(get: { session.showsGamutWarning },
                                                                  set: { session.showsGamutWarning = $0 }))
                                .assignableShortcut("CMYK Gamut Warning")
                                .disabled(session.document == nil)
                            Divider()
                            Menu(String(localized: "Profile", bundle: L10n.bundle)) {
                                let current = session.proofProfile ?? CMYK.chosen
                                ForEach(CMYK.installed()) { profile in
                                    Toggle(profile.name, isOn: Binding(get: { current?.name == profile.name },
                                                                       set: { if $0 { session.proofProfile = profile } }))
                                }
                                Divider()
                                Button(String(localized: "Load Profile…", bundle: L10n.bundle)) { loadCMYKProfile() }
                            }
                        }
                        Group {
                            Divider()
                            Menu(String(localized: "Show", bundle: L10n.bundle)) {
                                Toggle(String(localized: "Grid", bundle: L10n.bundle), isOn: Binding(get: { session.showsGrid }, set: { session.showsGrid = $0 }))
                                    .configuredKeyboardShortcut("'").disabled(session.document == nil)
                                Toggle(String(localized: "Guides", bundle: L10n.bundle), isOn: Binding(get: { session.showsGuides }, set: { session.showsGuides = $0 }))
                                    .configuredKeyboardShortcut(";").disabled(session.document == nil)
                            }
                            Button(String(localized: "Grid Settings…", bundle: L10n.bundle)) { Task { await applicationDelegate.projects.gridSettings() } }
                                .disabled(session.document == nil)
                            Toggle(String(localized: "Rulers", bundle: L10n.bundle), isOn: Binding(get: { session.showsRulers }, set: { session.showsRulers = $0 }))
                                .configuredKeyboardShortcut("r").disabled(session.document == nil)
                            Divider()
                            Toggle(String(localized: "Snap", bundle: L10n.bundle), isOn: Binding(get: { session.snapEnabled }, set: { session.snapEnabled = $0 }))
                                .configuredKeyboardShortcut(";", modifiers: [.command, .shift]).disabled(session.document == nil)
                            Menu(String(localized: "Snap To", bundle: L10n.bundle)) {
                                Toggle(String(localized: "Guides", bundle: L10n.bundle), isOn: Binding(get: { session.snapToGuides }, set: { session.snapToGuides = $0 }))
                                    .disabled(session.document == nil)
                                Toggle(String(localized: "Grid", bundle: L10n.bundle), isOn: Binding(get: { session.snapToGrid }, set: { session.snapToGrid = $0 }))
                                    .disabled(session.document == nil)
                                Toggle(String(localized: "Layers", bundle: L10n.bundle), isOn: Binding(get: { session.snapToLayers }, set: { session.snapToLayers = $0 }))
                                    .disabled(session.document == nil)
                                Toggle(String(localized: "Document Bounds", bundle: L10n.bundle), isOn: Binding(get: { session.snapToDocumentBounds },
                                                                        set: { session.snapToDocumentBounds = $0 }))
                                    .disabled(session.document == nil)
                            }
                            Divider()
                            Toggle(String(localized: "Lock Guides", bundle: L10n.bundle), isOn: Binding(get: { session.locksGuides }, set: { session.locksGuides = $0 }))
                                .configuredKeyboardShortcut(";", modifiers: [.command, .option]).disabled(session.document == nil)
                            Button(String(localized: "Clear Guides", bundle: L10n.bundle)) { session.clearGuides() }
                                .disabled(!session.canClearGuides)
                        }
                    }
                    // ⌘H toggles the Move tool's transform controls instead of hiding the app, so Hide keeps its
                    // place in the app menu without the shortcut.
                    CommandGroup(replacing: .appVisibility) {
                        Button(String(localized: "Hide Compositor", bundle: L10n.bundle)) { NSApp.hide(nil) }
                        Button(String(localized: "Hide Others", bundle: L10n.bundle)) { NSApp.hideOtherApplications(nil) }
                            .configuredKeyboardShortcut("h", modifiers: [.command, .option])
                        Button(String(localized: "Show All", bundle: L10n.bundle)) { NSApp.unhideAllApplications(nil) }
                    }
                }
                CommandGroup(replacing: .pasteboard) {
                    // Canvas pixels when the canvas has focus; text fields keep their own editing.
                    // Cut, Copy and Paste check when chosen rather than through .disabled: what they depend on
                    // (the pasteboard, the copied pixels, the busy flag) isn't observed, so a disabled state could
                    // go stale — the first Paste after a Copy used to beep until something else refreshed the menu.
                    Button(String(localized: "Cut", bundle: L10n.bundle)) {
                        if NSApp.keyWindow?.firstResponder is NSTextView { NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil) }
                        else if session.selection != nil, session.canCopyPixels { Task { await session.cutSelection() } }
                        else { NSSound.beep() }
                    }
                        .configuredKeyboardShortcut("x")
                    Button(String(localized: "Copy", bundle: L10n.bundle)) {
                        if NSApp.keyWindow?.firstResponder is NSTextView { NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) }
                        else if session.canCopyPixels || session.canCopyLayer { session.copySelection() }
                        else { NSSound.beep() }
                    }
                        .configuredKeyboardShortcut("c")
                    Button(String(localized: "Copy Merged", bundle: L10n.bundle)) { session.copyMergedSelection() }
                        .configuredKeyboardShortcut("c", modifiers: [.command, .shift]).disabled(!session.canCopyMerged)
                    Button(String(localized: "Paste", bundle: L10n.bundle)) {
                        // On the New canvas screen an image on the clipboard makes the canvas, even with a size field
                        // being typed in; a size copied as text still goes into the field.
                        if session.canPasteImageAsNewCanvas { Task { await session.pasteImageAsNewCanvas() } }
                        else if NSApp.keyWindow?.firstResponder is NSTextView { NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) }
                        else if applicationDelegate.workspace.pasteCopiedLayer() { }
                        else if session.canPaste { session.paste() }
                        else { NSSound.beep() }
                    }
                        .configuredKeyboardShortcut("v")
                }
                CommandGroup(after: .pasteboard) {
                    Divider()
                    Button(String(localized: "Keyboard Shortcuts…", bundle: L10n.bundle)) { ShortcutSettings.shared.show() }
                    // Photoshop's fill shortcuts; in a text field they keep their text meaning.
                    Button(String(localized: "Fill with Foreground Color", bundle: L10n.bundle)) {
                        if NSApp.keyWindow?.firstResponder is NSTextView {
                            NSApp.sendAction(#selector(NSResponder.deleteWordBackward(_:)), to: nil, from: nil)
                        } else { Task { await session.fillSelection(with: .foreground) } }
                    }
                        .configuredKeyboardShortcut(.delete, modifiers: .option).disabled(!session.canEditPixels)
                    Button(String(localized: "Fill with Background Color", bundle: L10n.bundle)) {
                        if NSApp.keyWindow?.firstResponder is NSTextView {
                            NSApp.sendAction(#selector(NSResponder.deleteToBeginningOfLine(_:)), to: nil, from: nil)
                        } else { Task { await session.fillSelection(with: .background) } }
                    }
                        .configuredKeyboardShortcut(.delete, modifiers: .command).disabled(!session.canEditPixels)
                    Button(String(localized: "Clear Selection Pixels", bundle: L10n.bundle)) { Task { await session.clearSelectedPixels() } }
                        .disabled(session.selection == nil || !session.canEditPixels)
                    Button(String(localized: "Content-Aware Fill…", bundle: L10n.bundle)) { session.beginFilter(.contentAwareFill) }
                        .configuredKeyboardShortcut(.delete, modifiers: .shift).disabled(!session.canContentAwareFill)
                }
                CommandMenu(String(localized: "Select", bundle: L10n.bundle)) {
                    // A field being edited keeps its own Select All: offer it to the responder chain
                    // first, which covers every kind of text control rather than NSTextView alone,
                    // and select the canvas only when nothing there wanted it.
                    Button(String(localized: "All", bundle: L10n.bundle)) {
                        if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) { return }
                        guard session.document != nil else { return }
                        session.selectAll()
                    }
                        // Never disabled: on macOS this menu item is what binds Cmd-A to selectAll:, so
                        // switching it off takes Select All away from every text field too. With no
                        // document and nothing being edited the action simply does nothing.
                        .configuredKeyboardShortcut("a")
                    Button(String(localized: "Deselect", bundle: L10n.bundle)) { session.deselect() }
                        .configuredKeyboardShortcut("d").disabled(session.selection == nil || !session.canEditSelection)
                    Button(String(localized: "Inverse", bundle: L10n.bundle)) { session.invertSelection() }
                        .configuredKeyboardShortcut("i", modifiers: [.command, .shift])
                        .disabled(session.selection == nil || !session.canEditSelection)
                    Button(String(localized: "Layer's Pixels", bundle: L10n.bundle)) {
                        if let id = session.activeLayerID { session.loadLayerSelection(layerID: id) }
                    }
                        .disabled(session.activeLayer?.asset == nil || !session.canEditSelection)
                    Button(String(localized: "Subject", bundle: L10n.bundle)) { Task { await session.selectSubject() } }
                        .configuredKeyboardShortcut("a", modifiers: [.command, .option])
                        .disabled(!session.canSelectSubject)
                    Button(String(localized: "Color Range…", bundle: L10n.bundle)) { session.beginColorRange() }
                        .disabled(!session.canSelectColorRange)
                    Button(String(localized: "Mask's Black Areas", bundle: L10n.bundle)) {
                        if let id = session.activeLayerID { session.loadMaskSelection(layerID: id) }
                    }
                        .disabled(session.activeLayer?.mask == nil || !session.canEditSelection)
                    Divider()
                    Button(String(localized: "Expand…", bundle: L10n.bundle)) { session.promptSelectionAmount(.expand) }
                        .disabled(!session.canModifySelection)
                    Button(String(localized: "Contract…", bundle: L10n.bundle)) { session.promptSelectionAmount(.contract) }
                        .disabled(!session.canModifySelection)
                    Button(String(localized: "Feather…", bundle: L10n.bundle)) { session.promptSelectionAmount(.feather) }
                        .disabled(!session.canModifySelection)
                }
                CommandMenu(String(localized: "Image", bundle: L10n.bundle)) {
                    Button(String(localized: "Curves…", bundle: L10n.bundle)) { session.beginFilter(.curves) }
                        .configuredKeyboardShortcut("m").disabled(!session.canAdjustColors || session.hueSaturation != nil)
                    Button(String(localized: "Levels…", bundle: L10n.bundle)) { session.beginLevels() }
                        .configuredKeyboardShortcut("l").disabled(!session.canAdjustColors || session.hueSaturation != nil)
                    Button(String(localized: "Hue/Saturation…", bundle: L10n.bundle)) { session.beginHueSaturation() }
                        .configuredKeyboardShortcut("u").disabled(!session.canAdjustColors)
                    ForEach([FilterKind.blackWhite, .colorBalance, .exposure, .gradientMap, .grain], id: \.self) { kind in
                        Button(L10n.text(kind.rawValue) + "…") { session.beginFilter(kind) }
                            .disabled(!session.canAdjustColors || session.hueSaturation != nil)
                    }
                    Button(session.isMaskSelected ? String(localized: "Invert Mask", bundle: L10n.bundle) : String(localized: "Invert", bundle: L10n.bundle)) { Task { await session.invertPixels() } }
                        .configuredKeyboardShortcut("i")
                        .disabled(!session.canInvert)
                    Divider()
                    Button(String(localized: "Canvas Size…", bundle: L10n.bundle)) { Task { await applicationDelegate.projects.canvasSize() } }
                        .configuredKeyboardShortcut("c", modifiers: [.command, .option])
                        .disabled(session.document == nil || !applicationDelegate.projects.canStart)
                    Button(String(localized: "Image Size…", bundle: L10n.bundle)) { Task { await applicationDelegate.projects.imageSize() } }
                        .configuredKeyboardShortcut("i", modifiers: [.command, .option])
                        .disabled(session.document == nil || !applicationDelegate.projects.canStart)
                    Button(String(localized: "Trim…", bundle: L10n.bundle)) { Task { await applicationDelegate.projects.trim() } }
                        .disabled(session.document == nil || !applicationDelegate.projects.canStart)
                    Group {
                        Divider()
                        Button(String(localized: "Rotate Canvas 90° Clockwise", bundle: L10n.bundle)) { session.rotateCanvas(clockwise: true) }
                            .disabled(!session.canEditLayers)
                        Button(String(localized: "Rotate Canvas 90° Counterclockwise", bundle: L10n.bundle)) { session.rotateCanvas(clockwise: false) }
                            .disabled(!session.canEditLayers)
                        Button(String(localized: "Flip Canvas Horizontal", bundle: L10n.bundle)) { session.flipCanvas(horizontally: true) }
                            .disabled(!session.canEditLayers)
                        Button(String(localized: "Flip Canvas Vertical", bundle: L10n.bundle)) { session.flipCanvas(horizontally: false) }
                            .disabled(!session.canEditLayers)
                    }
                }
                CommandMenu(String(localized: "Filter", bundle: L10n.bundle)) {
                    Button(session.lastFilter.map { String(localized: "Last Filter: ", bundle: L10n.bundle) + L10n.text($0.rawValue) } ?? String(localized: "Last Filter", bundle: L10n.bundle)) {
                        Task { await session.repeatLastFilter() }
                    }
                        // ⌃⌘F, as in Photoshop; ⌘F is the command palette.
                        .configuredKeyboardShortcut("f", modifiers: [.command, .control]).disabled(!session.canRepeatLastFilter)
                    Divider()
                    ForEach(FilterKind.allCases.filter { $0 != .contentAwareFill && !$0.isImageAdjustment }, id: \.self) { kind in
                        Button(L10n.text(kind.rawValue) + "…") { session.beginFilter(kind) }
                            .disabled(!(kind == .vignette ? session.canVignette : session.canAdjustColors) || session.hueSaturation != nil)
                    }
                }
                CommandMenu(String(localized: "Layer", bundle: L10n.bundle)) {
                    Menu(String(localized: "New Adjustment Layer", bundle: L10n.bundle)) {
                        ForEach(AdjustmentKind.allCases, id: \.self) { kind in
                            Button(L10n.text(kind.rawValue) + (kind.isEditable ? "…" : "")) { session.addAdjustment(kind) }
                        }
                    }.disabled(!session.canEditLayers || session.document == nil)
                    Button(String(localized: "Edit Adjustment…", bundle: L10n.bundle)) {
                        session.adjustmentEditingID = session.activeLayerID
                    }.disabled(!session.canEditLayers || session.activeLayer?.adjustment == nil)
                    Divider()
                    Button(session.canTransformSelection ? String(localized: "Transform Selection", bundle: L10n.bundle) : String(localized: "Transform Layer", bundle: L10n.bundle)) { session.transformCommand() }
                        .configuredKeyboardShortcut("t").disabled(!session.canTransform && !session.canTransformSelection)
                    Button(session.selection == nil ? String(localized: "Duplicate Layer", bundle: L10n.bundle) : String(localized: "Layer via Copy", bundle: L10n.bundle)) { session.layerViaCopy() }
                        .configuredKeyboardShortcut("j").disabled(!session.canCopyPixels && !(session.selection == nil && session.canEditLayers && session.activeLayer != nil))
                    Divider()
                    Button(session.activeLayer?.maskSourceID == nil ? String(localized: "Create Clipping Mask", bundle: L10n.bundle) : String(localized: "Release Clipping Mask", bundle: L10n.bundle)) {
                        if let id = session.activeLayerID { session.toggleClippingMask(id) }
                    }
                    .configuredKeyboardShortcut("g", modifiers: [.command, .option])
                    .disabled(session.activeLayerID.map { !session.canToggleClippingMask($0) } ?? true)
                    Divider()
                    Button(String(localized: "Group Selected Layers", bundle: L10n.bundle)) { session.groupSelectedLayers() }
                        .configuredKeyboardShortcut("g").disabled(!session.canEditLayers)
                    Button(String(localized: "Ungroup Layers", bundle: L10n.bundle)) { session.ungroupLayers() }
                        .configuredKeyboardShortcut("g", modifiers: [.command, .shift]).disabled(!session.canUngroupLayers)
                    Button(String(localized: "Move Out of Folder", bundle: L10n.bundle)) { session.moveActiveLayerOutOfGroup() }
                        .disabled(!session.canEditLayers || session.activeLayer?.parentID == nil)
                    Button(String(localized: "New Blank Layer", bundle: L10n.bundle)) { session.addBlankLayer() }
                        .configuredKeyboardShortcut("n", modifiers: [.command, .shift]).disabled(!session.canEditLayers)
                    Button(String(localized: "Rename Layer…", bundle: L10n.bundle)) { session.renamingLayerID = session.activeLayerID }
                        .disabled(!session.canEditLayers || session.activeLayer == nil)
                    Button(session.activeLayer?.isVisible == false ? String(localized: "Show Layer", bundle: L10n.bundle) : String(localized: "Hide Layer", bundle: L10n.bundle)) {
                        if let id = session.activeLayerID { session.toggleLayerVisibility(id) }
                    }.disabled(!session.canEditLayers || session.activeLayer == nil)
                    Divider()
                    Button(String(localized: "Move Layer Up", bundle: L10n.bundle)) { session.moveActiveLayer(by: 1) }
                        .configuredKeyboardShortcut("]").disabled(!session.canMoveActiveLayer(by: 1))
                    Button(String(localized: "Move Layer Down", bundle: L10n.bundle)) { session.moveActiveLayer(by: -1) }
                        .configuredKeyboardShortcut("[").disabled(!session.canMoveActiveLayer(by: -1))
                    Group {
                        Button(session.mergeTitle) { session.mergeLayers() }
                            .configuredKeyboardShortcut("e").disabled(!session.canMergeLayers)
                        Divider()
                        Button(String(localized: "Flip Layer Horizontal", bundle: L10n.bundle)) { session.flipLayers(horizontally: true) }
                            .disabled(!session.canTransform)
                        Button(String(localized: "Flip Layer Vertical", bundle: L10n.bundle)) { session.flipLayers(horizontally: false) }
                            .disabled(!session.canTransform)
                    }
                    Divider()
                    Button(session.selectedEffect != nil ? String(localized: "Delete ", bundle: L10n.bundle) + L10n.text(session.selectedEffect!.kind.rawValue) : session.isMaskSelected && session.activeLayer?.mask != nil ? String(localized: "Delete Layer Mask", bundle: L10n.bundle) : session.selectedLayerIDs.count > 1 ? String(localized: "Delete Layers", bundle: L10n.bundle) : String(localized: "Delete Layer", bundle: L10n.bundle)) {
                        session.deleteLayerOrMask()
                    }
                        .disabled(!session.canEditLayers || session.activeLayer == nil)
                }
            }
            .environment(\.locale, Locale(identifier: languageSettings.language.identifier))
    }

    /// View › CMYK › Profile › Load Profile: a CMYK ICC profile picked from anywhere, kept and chosen.
    private func loadCMYKProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "icc") ?? .data, UTType(filenameExtension: "icm") ?? .data]
        panel.message = String(localized: "Choose a CMYK ICC profile, such as the one your printer gave you", bundle: L10n.bundle)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { session.proofProfile = try CMYK.load(url) }
        catch { session.importError = error.localizedDescription }
    }
}
