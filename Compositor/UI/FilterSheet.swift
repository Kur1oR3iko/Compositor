import AppKit
import SwiftUI

/// The open filter's panel: its settings, Preview, and Cancel / OK.
struct FilterSheet: View {
    @Bindable var session: EditorSession
    private var edit: FilterEdit? { session.filterEdit }
    private var settings: FilterSettings { edit?.settings ?? FilterSettings() }
    private func update(_ change: (inout FilterSettings) -> Void) {
        var value = settings
        change(&value)
        session.updateFilter(value, preview: edit?.preview ?? true)
    }

    private var isCameraRaw: Bool { edit?.kind == .cameraRaw }
    /// The widest slider title in the panel, so every slider starts and ends in the same place.
    @State private var labelWidth: CGFloat = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch edit?.kind ?? .gaussianBlur {
            case .curves:
                CurvesControls(settings: Binding(get: { settings.curves }, set: { new in update { $0.curves = new } }))
            case .exposure:
                control(String(localized: "Exposure", bundle: L10n.bundle), \.exposure.exposure, range: ExposureSettings.exposureRange, unit: "", decimals: 2, logarithmic: false)
                control(String(localized: "Offset", bundle: L10n.bundle), \.exposure.offset, range: ExposureSettings.offsetRange, unit: "", decimals: 4, logarithmic: false)
                control(String(localized: "Gamma", bundle: L10n.bundle), \.exposure.gamma, range: ExposureSettings.gammaRange, unit: "", decimals: 2, logarithmic: true)
            case .gradientMap:
                GradientMapControls(settings: Binding(get: { settings.gradientMap }, set: { new in update { $0.gradientMap = new } }),
                                    pick: { session.openGradientMapColorPicker(highlights: $0) })
            case .blackWhite:
                // Each slider says how bright that family of colors becomes, as Photoshop's do.
                control(String(localized: "Reds", bundle: L10n.bundle), \.blackWhite.reds, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(0))
                control(String(localized: "Yellows", bundle: L10n.bundle), \.blackWhite.yellows, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(60))
                control(String(localized: "Greens", bundle: L10n.bundle), \.blackWhite.greens, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(120))
                control(String(localized: "Cyans", bundle: L10n.bundle), \.blackWhite.cyans, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(180))
                control(String(localized: "Blues", bundle: L10n.bundle), \.blackWhite.blues, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(240))
                control(String(localized: "Magentas", bundle: L10n.bundle), \.blackWhite.magentas, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(300))
                Toggle("Tint", isOn: flag(\.blackWhite.tint))
                    .help("Color the result while keeping its tones, for a sepia or a cyanotype")
                if settings.blackWhite.tint {
                    control(String(localized: "Hue", bundle: L10n.bundle), \.blackWhite.tintHue, range: 0...360, unit: "°", decimals: 0, logarithmic: false, track: .plain)
                    control(String(localized: "Saturation", bundle: L10n.bundle), \.blackWhite.tintSaturation, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                            track: .saturation(settings.blackWhite.tintHue))
                }
            case .cameraRaw:
                CameraRawControls(session: session)
                    .frame(maxHeight: .infinity, alignment: .top)
            case .colorBalance:
                Text("Shadows").font(.headline)
                control(String(localized: "Cyan / Red", bundle: L10n.bundle), \.colorBalance.shadowCyanRed, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.cyanRedTrack)
                control(String(localized: "Magenta / Green", bundle: L10n.bundle), \.colorBalance.shadowMagentaGreen, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.magentaGreenTrack)
                control(String(localized: "Yellow / Blue", bundle: L10n.bundle), \.colorBalance.shadowYellowBlue, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.yellowBlueTrack)
                Text("Midtones").font(.headline)
                control(String(localized: "Cyan / Red", bundle: L10n.bundle), \.colorBalance.midCyanRed, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.cyanRedTrack)
                control(String(localized: "Magenta / Green", bundle: L10n.bundle), \.colorBalance.midMagentaGreen, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.magentaGreenTrack)
                control(String(localized: "Yellow / Blue", bundle: L10n.bundle), \.colorBalance.midYellowBlue, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.yellowBlueTrack)
                Text("Highlights").font(.headline)
                control(String(localized: "Cyan / Red", bundle: L10n.bundle), \.colorBalance.highlightCyanRed, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.cyanRedTrack)
                control(String(localized: "Magenta / Green", bundle: L10n.bundle), \.colorBalance.highlightMagentaGreen, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.magentaGreenTrack)
                control(String(localized: "Yellow / Blue", bundle: L10n.bundle), \.colorBalance.highlightYellowBlue, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.yellowBlueTrack)
                Toggle("Preserve Luminosity", isOn: flag(\.colorBalance.preserveLuminosity))
                    .help("Put each pixel's brightness back afterwards, so only the color moves")
            case .grain:
                control(String(localized: "Amount", bundle: L10n.bundle), \.grain.amount, range: GrainSettings.amountRange, unit: "", decimals: 0, logarithmic: false)
                control(String(localized: "Size", bundle: L10n.bundle), \.grain.size, range: GrainSettings.sizeRange, unit: String(localized: "px", bundle: L10n.bundle), decimals: 1, logarithmic: true)
                control(String(localized: "Roughness", bundle: L10n.bundle), \.grain.roughness, range: GrainSettings.roughnessRange, unit: "", decimals: 0, logarithmic: false)
            case .removeBackground:
                Text("Hide the background behind a layer mask, keeping the foreground subjects. The pixels stay, so the background can be painted back at any time.")
                    .fixedSize(horizontal: false, vertical: true)
                Picker("Quality", selection: Binding(get: { settings.backgroundQuality },
                                                     set: { new in update { $0.backgroundQuality = new } })) {
                    ForEach(BackgroundQuality.allCases, id: \.self) { Text(L10n.text($0.rawValue)).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
                .help("Basic is quick; Advanced refines the mask against the layer's own detail, for hair and fur")
                if settings.backgroundQuality == .advanced {
                    control(String(localized: "Refine", bundle: L10n.bundle), \.refineEdges, range: 0...40, unit: String(localized: "px", bundle: L10n.bundle), decimals: 0, logarithmic: false)
                        .help("Pull the mask onto the image's own edges, which recovers hair and fur")
                    control(String(localized: "Contrast", bundle: L10n.bundle), \.matteContrast, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                        .help("Clear the haze that leaves background showing through thin areas")
                    control(String(localized: "Shift Edge", bundle: L10n.bundle), \.shiftEdge, range: -10...10, unit: String(localized: "px", bundle: L10n.bundle), decimals: 0, logarithmic: false)
                        .help("Shrink the mask to drop the rim of background color around the subject, or grow it")
                }
            case .contentAwareFill:
                Text("Fill the selection using surrounding pixels from this layer.")
                    .fixedSize(horizontal: false, vertical: true)
            case .gaussianBlur:
                control(String(localized: "Radius", bundle: L10n.bundle), \.radius, range: 0.1...250, unit: String(localized: "px", bundle: L10n.bundle), decimals: 1, logarithmic: true)
                Toggle("Preserve Transparency", isOn: flag(\.preserveTransparency))
                    .help("Blur only the colors, keeping the layer's outline and transparency as they are")
            case .progressiveBlur:
                Text("Click and drag two points on canvas")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Text("Shape")
                    Picker("Shape", selection: flag(\.progressiveRadial)) {
                        Text("Linear").tag(false)
                        Text("Radial").tag(true)
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                    .help("Linear blurs along the line; Radial keeps the start sharp and blurs outwards")
                }
                control("From", \.progressiveFrom, range: 0...250, unit: "px", decimals: 1, logarithmic: false)
                    .help("The blur where the line starts")
                control("To", \.progressiveTo, range: 0...250, unit: "px", decimals: 1, logarithmic: false)
                    .help("The blur where the line ends, and past it")
                Toggle(String(localized: "Reverse Blur", defaultValue: "Invert", bundle: L10n.bundle, comment: "Swap the blur at the start and end"), isOn: flag(\.progressiveInverted))
                    .help("Swap From and To: blur the start and sharpen toward the end")
            case .motionBlur:
                control(String(localized: "Angle", bundle: L10n.bundle), \.angle, range: -90...90, unit: "°", decimals: 0, logarithmic: false)
                control(String(localized: "Distance", bundle: L10n.bundle), \.distance, range: 1...2000, unit: String(localized: "px", bundle: L10n.bundle), decimals: 0, logarithmic: true)
            case .addNoise:
                control(String(localized: "Amount", bundle: L10n.bundle), \.amount, range: 0.1...400, unit: "%", decimals: 1, logarithmic: true)
                HStack(spacing: 10) {
                    Text("Distribution")
                    Picker("Distribution", selection: flag(\.gaussian)) {
                        Text("Uniform").tag(false)
                        Text("Gaussian").tag(true)
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }
                Toggle("Monochromatic", isOn: flag(\.monochromatic))
            case .dither:
                ditherControls
            case .scanlines:
                scanlinesControls
            case .vignette:
                HStack(spacing: 8) {
                    Text("Color").frame(width: 95, alignment: .leading)
                    Button { session.openVignetteColorPicker() } label: {
                        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
                        shape.fill(Color(.sRGB, red: settings.vignetteColor.red,
                                         green: settings.vignetteColor.green, blue: settings.vignetteColor.blue))
                            .overlay { shape.inset(by: 1).strokeBorder(.white, lineWidth: 1.5) }
                            .overlay { shape.strokeBorder(.black, lineWidth: 1) }
                            .frame(width: 24, height: 24)
                            .contentShape(shape)
                    }
                    .buttonStyle(.plain)
                    .help("Choose the vignette color")
                    Spacer()
                }
                control(String(localized: "Amount", bundle: L10n.bundle), \.vignetteAmount, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                    .help("Blend the chosen color into the edges while keeping the center unchanged")
                control(String(localized: "Midpoint", bundle: L10n.bundle), \.vignetteMidpoint, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                control(String(localized: "Roundness", bundle: L10n.bundle), \.vignetteRoundness, range: -100...100, unit: "", decimals: 0, logarithmic: false)
                control(String(localized: "Feather", bundle: L10n.bundle), \.vignetteFeather, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                control(String(localized: "Highlights", bundle: L10n.bundle), \.vignetteHighlights, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                    .help("Protect bright areas near the edge")
            case .bloomGlow:
                control(String(localized: "Amount", bundle: L10n.bundle), \.bloomAmount, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                control(String(localized: "Radius", bundle: L10n.bundle), \.bloomRadius, range: 1...150, unit: String(localized: "px", bundle: L10n.bundle), decimals: 0, logarithmic: true)
            case .tonalContrast:
                control(String(localized: "Amount", bundle: L10n.bundle), \.tonalAmount, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                control(String(localized: "Shadows", bundle: L10n.bundle), \.tonalShadows, range: -100...100, unit: "%", decimals: 0, logarithmic: false)
                control(String(localized: "Midtones", bundle: L10n.bundle), \.tonalMidtones, range: -100...100, unit: "%", decimals: 0, logarithmic: false)
                control(String(localized: "Highlights", bundle: L10n.bundle), \.tonalHighlights, range: -100...100, unit: "%", decimals: 0, logarithmic: false)
                control(String(localized: "Radius", bundle: L10n.bundle), \.tonalRadius, range: 1...100, unit: String(localized: "px", bundle: L10n.bundle), decimals: 0, logarithmic: true)
            case .lensCorrection:
                control(String(localized: "Remove Distortion", bundle: L10n.bundle), \.distortion, range: -100...100, unit: "", decimals: 0, logarithmic: false)
                Text("Positive straightens lines that bow outward (barrel); negative, lines that bow inward (pincushion).")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Toggle("Preview", isOn: Binding(get: { edit?.preview ?? true },
                                            set: { session.updateFilter(settings, preview: $0) }))
            if let error = edit?.previewError {
                Text(error).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if session.adjustmentOriginal == nil && session.selection != nil {
                Text("Limited to the selection").font(.callout).foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Button("Cancel") { session.cancelFilter() }.configuredNativeShortcut(.escape)
                Spacer()
                // While the preview is being worked out (Remove Background's mask, Content-Aware Fill) OK waits, so
                // the panel says what it is waiting for rather than showing a disabled button and nothing else.
                // Only the slow filters say so: a quick preview (Dither, a blur) toggling this at every slider step would
                // make the panel flicker as it grows and shrinks.
                if edit?.committing == true || (edit?.preparing == true && edit?.kind.isAutomatic == true) {
                    ProgressView().controlSize(.small)
                    Text(edit?.committing == true ? String(localized: "Applying…", bundle: L10n.bundle) : String(localized: "Working…", bundle: L10n.bundle))
                        .font(.callout).foregroundStyle(.secondary)
                }
                Button("OK") { Task { await session.commitFilter() } }
                    .configuredNativeShortcut(.return).buttonStyle(.borderedProminent)
                    .disabled(edit?.kind.isAutomatic == true && (edit?.preparing == true || edit?.previewError != nil))
            }
        }
        .onPreferenceChange(LabelWidthKey.self) { labelWidth = max(60, $0) }
        .padding(24)
        .frame(width: isCameraRaw ? FloatingPanelController.dockedWidth : 380)
        .frame(maxHeight: isCameraRaw ? .infinity : nil, alignment: .top)
        .fixedSize(horizontal: false, vertical: !isCameraRaw)

        .disabled(edit?.committing == true)
        // Filter colors preview live while the app's color picker is open.
        .onChange(of: session.colorPicker?.color) { _, _ in
            session.previewGradientMapColor()
            session.previewVignetteColor()
            session.previewDitherColor()
        }
    }

    @ViewBuilder private var ditherControls: some View {
        let dither = settings.dither
        Picker("Style", selection: Binding(get: { dither.style }, set: { new in update { $0.dither.style = new } })) {
            ForEach(DitherStyle.groups.indices, id: \.self) { group in
                if group > 0 { Divider() }
                ForEach(DitherStyle.groups[group], id: \.self) { Text(L10n.text($0.rawValue)).tag($0) }
            }
        }
        if dither.style.usesPixelSize {
        control(String(localized: "Pixel Size", bundle: L10n.bundle), \.dither.pixelSize, range: DitherSettings.pixelSizeRange, unit: String(localized: "px", bundle: L10n.bundle), decimals: 0, logarithmic: false)
            .help("Make each dithered pixel this many pixels across, for a chunky old-screen look")
        }
        if dither.style == .ascii {
            control(String(localized: "Text Size", bundle: L10n.bundle), \.dither.textSize, range: DitherSettings.textSizeRange, unit: String(localized: "px", bundle: L10n.bundle), decimals: 0, logarithmic: false)
                .help("The height of each line of characters")
        }
        if dither.style.isHalftone {
            control(String(localized: "Cell Size", bundle: L10n.bundle), \.dither.cellSize, range: DitherSettings.cellSizeRange, unit: String(localized: "px", bundle: L10n.bundle), decimals: 0, logarithmic: false)
        }
        if dither.style.isHalftone {
            control(String(localized: "Angle", bundle: L10n.bundle), \.dither.angle, range: -90...90, unit: "°", decimals: 0, logarithmic: false)
        }
        if dither.style == .ascii {
            HStack(spacing: 10) {
                Text("Characters")
                TextField("Characters", text: Binding(get: { dither.characters }, set: { new in update { $0.dither.characters = new } }))
                    .textFieldStyle(.roundedBorder).font(.body.monospaced())
            }
            .help("The characters to draw with, in any order: each spot gets the one whose ink best matches its tone")
        }
        if dither.style.hasTones {
            control(String(localized: "Tones", bundle: L10n.bundle), \.dither.levels, range: DitherSettings.levelsRange, unit: "", decimals: 0, logarithmic: false)
                .help("Tones per channel: 2 is pure black and white")
        }
        if dither.style.diffuses {
            control(String(localized: "Diffusion", bundle: L10n.bundle), \.dither.diffusion, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                .help("How much of each pixel's error spreads to its neighbors. Less gives flatter areas")
        }
        control(String(localized: "Density", bundle: L10n.bundle), \.dither.density, range: -100...100, unit: "", decimals: 0, logarithmic: false)
            .help("More ink (darker) or less before dithering")
        control(String(localized: "Contrast", bundle: L10n.bundle), \.dither.contrast, range: -100...100, unit: "", decimals: 0, logarithmic: false)
        // A menu, like Style: the three choices as segments are wider than the panel, which then flips between
        // squeezing the row and wrapping it, resizing itself at every slider step.
        Picker("Colors", selection: Binding(get: { dither.colors }, set: { new in update { $0.dither.colors = new } })) {
            ForEach(DitherColors.allCases, id: \.self) { Text(L10n.text($0.rawValue)).tag($0) }
        }
        .fixedSize()
        if dither.colors == .twoColors {
            HStack(spacing: 8) {
                Text("Dark")
                swatch(dither.dark, help: String(localized: "Choose the dark color", bundle: L10n.bundle)) { session.openDitherColorPicker(light: false) }
                Text("Light").padding(.leading, 10)
                swatch(dither.light, help: String(localized: "Choose the light color", bundle: L10n.bundle)) { session.openDitherColorPicker(light: true) }
                Spacer()
            }
        }
        if dither.pixelSize > 1, dither.style.usesPixelSize {
            Picker("Pixel Shape", selection: Binding(get: { dither.pixelShape }, set: { new in update { $0.dither.pixelShape = new } })) {
                ForEach(DitherPixelShape.allCases, id: \.self) { Text(L10n.text($0.rawValue)).tag($0) }
            }
            .fixedSize()
            .help("Draw each chunky pixel as a solid square, or as a round dot like a dot-matrix screen")
        }
        if dither.style.drawsMarks {
            Toggle("Light on Dark", isOn: flag(\.dither.lightOnDark))
                .help("Draw the marks for the light tones on the dark color, like a glowing screen")
        }
    }

    @ViewBuilder private var scanlinesControls: some View {
        let lines = settings.scanlines
        control(String(localized: "Line Spacing", bundle: L10n.bundle), \.scanlines.lineSpacing, range: ScanlinesSettings.lineSpacingRange, unit: String(localized: "px", bundle: L10n.bundle), decimals: 0, logarithmic: false)
            .help("How far apart the screen's lines are")
        control(String(localized: "Thickness", bundle: L10n.bundle), \.scanlines.thickness, range: 5...100, unit: "%", decimals: 0, logarithmic: false)
            .help("How much of the gap a bright line fills; dimmer parts draw it thinner")
        control(String(localized: "Glow", bundle: L10n.bundle), \.scanlines.glow, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
            .help("Light blooming around the lines, like a CRT's phosphors")
        control(String(localized: "Dots", bundle: L10n.bundle), \.scanlines.dots, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
            .help("Break the lines into beads where the picture is darker than this, blending into solid lines where it's brighter")
        control(String(localized: "Displace", bundle: L10n.bundle), \.scanlines.displace, range: ScanlinesSettings.displaceRange, unit: String(localized: "px", bundle: L10n.bundle), decimals: 0, logarithmic: false)
            .help("Lift the lines where the picture is bright, or lower them when negative, so they swell into its shapes")
        control(String(localized: "Smoothness", bundle: L10n.bundle), \.scanlines.smoothness, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
            .help("How far the brightness is smoothed before it displaces the lines, from sharp ridges to rounded hills")
        control(String(localized: "Threshold", bundle: L10n.bundle), \.scanlines.threshold, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
            .help("Draw no line where the picture is darker than this, leaving the screen dark")
        control(String(localized: "Wobble", bundle: L10n.bundle), \.scanlines.wobble, range: ScanlinesSettings.wobbleRange, unit: String(localized: "px", bundle: L10n.bundle), decimals: 0, logarithmic: false)
            .help("Make the lines waver sideways down the screen, like a CRT losing sync")
        control(String(localized: "Color Split", bundle: L10n.bundle), \.scanlines.split, range: ScanlinesSettings.splitRange, unit: String(localized: "px", bundle: L10n.bundle), decimals: 0, logarithmic: false)
            .help("Move the red and blue apart, for colored fringes on the lines")
        control(String(localized: "Density", bundle: L10n.bundle), \.scanlines.density, range: -100...100, unit: "", decimals: 0, logarithmic: false)
            .help("Darker or lighter before the lines are drawn")
        control(String(localized: "Contrast", bundle: L10n.bundle), \.scanlines.contrast, range: -100...100, unit: "", decimals: 0, logarithmic: false)
        control(String(localized: "Black Level", bundle: L10n.bundle), \.scanlines.blackLevel, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
            .help("How bright the lines are where the picture is black, so they show even over black")
        Picker("Colors", selection: Binding(get: { lines.colors }, set: { new in update { $0.scanlines.colors = new } })) {
            ForEach(DitherColors.allCases, id: \.self) { Text(L10n.text($0.rawValue)).tag($0) }
        }
        .fixedSize()
        if lines.colors == .twoColors {
            HStack(spacing: 8) {
                Text("Dark")
                swatch(lines.dark, help: String(localized: "Choose the screen's color", bundle: L10n.bundle)) { session.openDitherColorPicker(light: false) }
                Text("Light").padding(.leading, 10)
                swatch(lines.light, help: String(localized: "Choose the lines' color", bundle: L10n.bundle)) { session.openDitherColorPicker(light: true) }
                Spacer()
            }
        }
    }

    private func swatch(_ color: AdjustmentColor, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
            shape.fill(Color(.sRGB, red: color.red, green: color.green, blue: color.blue))
                .overlay { shape.inset(by: 1).strokeBorder(.white, lineWidth: 1.5) }
                .overlay { shape.strokeBorder(.black, lineWidth: 1) }
                .frame(width: 24, height: 24)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .help(L10n.text(help))
    }

    private func flag(_ key: WritableKeyPath<FilterSettings, Bool>) -> Binding<Bool> {
        Binding(get: { settings[keyPath: key] }, set: { value in update { $0[keyPath: key] = value } })
    }

    /// The setting put back to its filter's default, as a double-click on a colored slider does.
    static func resetting(_ key: WritableKeyPath<FilterSettings, Double>, in settings: FilterSettings) -> FilterSettings {
        var value = settings
        value[keyPath: key] = FilterSettings()[keyPath: key]
        return value
    }

    static let cyanRedTrack = CameraRawSliderTrack.opposing(NSColor(srgbRed: 0.10, green: 0.72, blue: 0.80, alpha: 1),
                                                            NSColor(srgbRed: 0.86, green: 0.18, blue: 0.20, alpha: 1))
    static let magentaGreenTrack = CameraRawSliderTrack.opposing(NSColor(srgbRed: 0.80, green: 0.22, blue: 0.70, alpha: 1),
                                                                 NSColor(srgbRed: 0.24, green: 0.70, blue: 0.30, alpha: 1))
    static let yellowBlueTrack = CameraRawSliderTrack.opposing(NSColor(srgbRed: 0.95, green: 0.82, blue: 0.18, alpha: 1),
                                                               NSColor(srgbRed: 0.22, green: 0.40, blue: 0.92, alpha: 1))

    /// A slider plus an exact field. Logarithmic sliders give the small values used most most of the travel.
    /// A colored track draws the slider as Camera Raw's, where a double-click on the title or knob resets it.
    private func control(_ title: String, _ key: WritableKeyPath<FilterSettings, Double>, range: ClosedRange<Double>,
                         unit: String, decimals: Int, logarithmic: Bool, track: CameraRawSliderTrack? = nil) -> some View {
        let step = pow(10, Double(decimals))
        let reset = { update { $0 = Self.resetting(key, in: $0) } }
        return HStack(spacing: 10) {
            Text(L10n.text(title)).fixedSize()
                .background(GeometryReader { Color.clear.preference(key: LabelWidthKey.self, value: $0.size.width) })
                .frame(width: labelWidth, alignment: .leading)
                .onTapGesture(count: 2) { if track != nil { reset() } }
                .scrubbable(sensitivity: 1 / step,
                            value: Binding(get: { settings[keyPath: key] }, set: { value in update { $0[keyPath: key] = value } }),
                            range: range)
            if let track {
                CameraRawSlider(value: settings[keyPath: key], range: range, track: track,
                                help: String(localized: "\(L10n.text(title)). Double-click to reset.", bundle: L10n.bundle),
                                onChange: { value in update { $0[keyPath: key] = (value * step).rounded() / step } },
                                onReset: reset)
            } else {
                Slider(value: Binding(get: { logarithmic ? log(settings[keyPath: key]) : settings[keyPath: key] },
                                      set: { value in update { $0[keyPath: key] = ((logarithmic ? exp(value) : value) * step).rounded() / step } }),
                       in: logarithmic ? log(range.lowerBound)...log(range.upperBound) : range)
            }
            TextField(L10n.text(title), value: Binding(get: { settings[keyPath: key] }, set: { value in update { $0[keyPath: key] = value } }),
                      format: .number.precision(.fractionLength(0...decimals)))
                .frame(width: 56).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                .unitSuffix(unit)
        }
    }
}

/// Gradient Map's two colors, the gradient they make, and Reverse. The colors are swatches like the
/// tool rail's, and open the app's own color picker.
struct GradientMapControls: View {
    @Binding var settings: GradientMapSettings
    /// Opens the color picker on an end: false for Shadows, true for Highlights.
    let pick: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let ends = settings.ends
            LinearGradient(colors: [color(ends.dark), color(ends.light)], startPoint: .leading, endPoint: .trailing)
                .frame(height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.black.opacity(0.35)) }
                .accessibilityHidden(true)
            HStack(spacing: 20) {
                swatch(String(localized: "Shadows", bundle: L10n.bundle), settings.shadows) { pick(false) }
                swatch(String(localized: "Highlights", bundle: L10n.bundle), settings.highlights) { pick(true) }
                Spacer()
            }
            Toggle("Reverse", isOn: $settings.reversed)
        }
    }

    private func color(_ value: AdjustmentColor) -> Color { Color(.sRGB, red: value.red, green: value.green, blue: value.blue) }

    private func swatch(_ title: String, _ value: AdjustmentColor, action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return HStack(spacing: 8) {
            Button(action: action) {
                shape
                    .fill(color(value))
                    .overlay { shape.inset(by: 1).strokeBorder(.white, lineWidth: 1.5) }
                    .overlay { shape.strokeBorder(.black, lineWidth: 1) }
                    .frame(width: 24, height: 24)
                    .contentShape(shape)
            }
            .buttonStyle(.plain)
            .help(String(localized: "Choose the \(title.lowercased()) color", bundle: L10n.bundle))
            .accessibilityLabel(String(localized: "\(title) color", bundle: L10n.bundle))
            Text(L10n.text(title))
        }
    }
}

private struct LabelWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
