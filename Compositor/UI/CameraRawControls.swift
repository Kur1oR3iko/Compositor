import AppKit
import SwiftUI

/// Camera Raw Filter's adjustment column: the histogram, then Light, Color, Color Grading, Effects, Curve,
/// Color Mixer, Detail, Optics, Geometry, and Calibration.
struct CameraRawControls: View {
    @Bindable var session: EditorSession
    @State private var expanded: Set<Section> = [.light, .color, .colorGrading]
    @State private var optionMonitor: Any?

    private var settings: FilterSettings { session.filterEdit?.settings ?? FilterSettings() }
    private var raw: CameraRawSettings { settings.cameraRaw }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            histogram
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Section.allCases) { section in
                        disclosure(section)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 20)
            }
            .padding(.trailing, -20)
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear { installOptionMonitor() }
        .onDisappear { removeOptionMonitor() }
    }

    private var histogram: some View {
        let scope = session.filterEdit?.cameraRawScope
        let mode = session.filterEdit?.cameraRawScopeMode ?? .histogram
        return VStack(alignment: .leading, spacing: 4) {
            ZStack {
                graph(scope, mode: mode)
                    .frame(height: 110)
                    .background(Color.black.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                HStack {
                    clipButton(shadows: true)
                    Spacer()
                    clipButton(shadows: false)
                }
                .padding(4)
            }
            .contextMenu {
                Button("Histogram") { session.filterEdit?.cameraRawScopeMode = .histogram }
                Button("Vectorscope") { session.filterEdit?.cameraRawScopeMode = .vectorscope }
            }
            .help(mode == .histogram
                  ? String(localized: "Tones from black on the left to white on the right: blacks, shadows, midtones, highlights, whites. Control-click to show the vectorscope.", bundle: L10n.bundle)
                  : String(localized: "Hue around the wheel, saturation outward from the center. Control-click to show the histogram.", bundle: L10n.bundle))
            Text(readout)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .help("Red, green, and blue of the pixel under the pointer.")
        }
    }

    private var readout: String {
        guard let value = session.filterEdit?.cameraRawReadout else { return "R —   G —   B —" }
        return "R \(value.red)   G \(value.green)   B \(value.blue)"
    }

    private func clipButton(shadows: Bool) -> some View {
        let on = shadows ? session.filterEdit?.showsShadowClipping == true : session.filterEdit?.showsHighlightClipping == true
        return Button {
            if shadows { session.filterEdit?.showsShadowClipping.toggle() }
            else { session.filterEdit?.showsHighlightClipping.toggle() }
            if let edit = session.filterEdit { session.updateFilter(edit.settings, preview: edit.preview) }
        } label: {
            Image(systemName: "triangle.fill")
                .font(.caption2)
                .foregroundStyle(on ? (shadows ? Color.blue : Color.red) : Color.white.opacity(0.55))
        }
        .buttonStyle(.plain)
        .help(shadows ? String(localized: "Show clipped shadows in blue on the preview.", bundle: L10n.bundle) : String(localized: "Show clipped highlights in red on the preview.", bundle: L10n.bundle))
        .accessibilityLabel(shadows ? String(localized: "Shadow Clipping Indicator", bundle: L10n.bundle) : String(localized: "Highlight Clipping Indicator", bundle: L10n.bundle))
    }

    private func graph(_ scope: CameraRawScope?, mode: CameraRawScopeMode) -> some View {
        Canvas { context, size in
            guard let scope else { return }
            switch mode {
            case .histogram:
                let peak = scope.peak
                guard peak > 0 else { return }
                ribbon(scope.red, color: .red, peak: peak, in: context, size: size)
                ribbon(scope.green, color: .green, peak: peak, in: context, size: size)
                ribbon(scope.blue, color: .blue, peak: peak, in: context, size: size)
            case .vectorscope:
                let peak = scope.vectorscope.max() ?? 0
                guard peak > 0 else { return }
                let cell = size.width / CGFloat(CameraRawScope.scopeSide)
                for index in scope.vectorscope.indices where scope.vectorscope[index] > 0 {
                    let column = index % CameraRawScope.scopeSide
                    let row = index / CameraRawScope.scopeSide
                    let amount = min(1, scope.vectorscope[index] / peak)
                    let rect = CGRect(x: CGFloat(column) * cell, y: size.height - CGFloat(row + 1) * cell, width: cell + 0.2, height: cell + 0.2)
                    context.fill(Path(rect), with: .color(.white.opacity(0.15 + 0.85 * amount)))
                }
            }
        }
        .accessibilityLabel(mode == .histogram ? String(localized: "RGB histogram", bundle: L10n.bundle) : String(localized: "Vectorscope", bundle: L10n.bundle))
    }

    private func ribbon(_ bins: [Double], color: Color, peak: Double, in context: GraphicsContext, size: CGSize) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        for index in bins.indices {
            let x = CGFloat(index) * size.width / CGFloat(bins.count)
            let height = size.height * min(1, max(0, bins[index] / peak))
            path.addLine(to: CGPoint(x: x, y: size.height - height))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        context.fill(path, with: .color(color.opacity(0.55)))
    }

    @ViewBuilder private func disclosure(_ section: Section) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Button {
                    if expanded.contains(section) { expanded.remove(section) } else { expanded.insert(section) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: expanded.contains(section) ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .frame(width: 12)
                        Text(L10n.text(section.rawValue)).font(.headline)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text(section.rawValue))
                Spacer(minLength: 0)
                if section == .light, raw.adjustsLight {
                    eye(shown: session.filterEdit?.showsCameraRawLight ?? true, name: L10n.text("Light"), group: .light)
                    resetButton(section.group)
                }
                if section == .color, raw.adjustsColor {
                    eye(shown: session.filterEdit?.showsCameraRawColor ?? true, name: L10n.text("Color"), group: .color)
                    resetButton(section.group)
                }
                if section == .effects, raw.adjustsEffects {
                    eye(shown: session.filterEdit?.showsCameraRawEffects ?? true, name: L10n.text("Effects"), group: .effects)
                    resetButton(section.group)
                }
                if section == .curve, raw.adjustsCurve {
                    eye(shown: session.filterEdit?.showsCameraRawCurve ?? true, name: L10n.text("Curve"), group: .curve)
                    resetButton(section.group)
                }
                if section == .colorMixer, raw.adjustsMixer {
                    eye(shown: session.filterEdit?.showsCameraRawMixer ?? true, name: L10n.text("Color Mixer"), group: .mixer)
                    resetButton(section.group)
                }
                if section == .colorGrading, raw.adjustsGrading {
                    eye(shown: session.filterEdit?.showsCameraRawGrading ?? true, name: L10n.text("Color Grading"), group: .grading)
                    resetButton(section.group)
                }
                if section == .detail, raw.adjustsDetail {
                    eye(shown: session.filterEdit?.showsCameraRawDetail ?? true, name: L10n.text("Detail"), group: .detail)
                    resetButton(section.group)
                }
                if section == .optics, raw.adjustsOptics {
                    eye(shown: session.filterEdit?.showsCameraRawOptics ?? true, name: L10n.text("Optics"), group: .optics)
                    resetButton(section.group)
                }
                if section == .geometry, raw.adjustsGeometry {
                    eye(shown: session.filterEdit?.showsCameraRawGeometry ?? true, name: L10n.text("Geometry"), group: .geometry)
                    resetButton(section.group)
                }
                if section == .calibration, raw.adjustsCalibration {
                    eye(shown: session.filterEdit?.showsCameraRawCalibration ?? true, name: L10n.text("Calibration"), group: .calibration)
                    resetButton(section.group)
                }
            }
            if expanded.contains(section) {
                switch section {
                case .light: lightControls.padding(.leading, 18)
                case .color: colorControls.padding(.leading, 18)
                case .effects: effectsControls.padding(.leading, 18)
                case .curve: CameraRawCurveControls(session: session).padding(.leading, 18)
                case .colorMixer: CameraRawMixerControls(session: session).padding(.leading, 18)
                case .colorGrading: CameraRawGradingControls(session: session).padding(.leading, 18)
                case .detail: CameraRawDetailControls(session: session).padding(.leading, 18)
                case .optics: CameraRawOpticsControls(session: session).padding(.leading, 18)
                case .geometry: CameraRawGeometryControls(session: session).padding(.leading, 18)
                case .calibration: CameraRawCalibrationControls(session: session).padding(.leading, 18)
                }
            }
        }
    }

    private var lightControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            slider(String(localized: "Exposure", bundle: L10n.bundle), \.exposure, range: CameraRawSettings.exposureRange, decimals: 2, clipping: .highlights,
                   help: String(localized: "Brightens or darkens the whole picture, in stops of light. Hold Option to see clipped highlights.", bundle: L10n.bundle))
            slider(String(localized: "Contrast", bundle: L10n.bundle), \.contrast, range: CameraRawSettings.toneRange, decimals: 0, clipping: nil,
                   help: String(localized: "Makes light and dark tones more or less different, mostly around the middle.", bundle: L10n.bundle))
            slider(String(localized: "Highlights", bundle: L10n.bundle), \.highlights, range: CameraRawSettings.toneRange, decimals: 0, clipping: .highlights,
                   help: String(localized: "Adjusts the bright parts of the picture. Hold Option to see clipped highlights.", bundle: L10n.bundle))
            slider(String(localized: "Shadows", bundle: L10n.bundle), \.shadows, range: CameraRawSettings.toneRange, decimals: 0, clipping: .shadows,
                   help: String(localized: "Adjusts the dark parts of the picture. Hold Option to see clipped shadows.", bundle: L10n.bundle))
            slider(String(localized: "Whites", bundle: L10n.bundle), \.whites, range: CameraRawSettings.toneRange, decimals: 0, clipping: .highlights,
                   help: String(localized: "Sets the brightest point. Hold Option to see clipped highlights.", bundle: L10n.bundle))
            slider(String(localized: "Blacks", bundle: L10n.bundle), \.blacks, range: CameraRawSettings.toneRange, decimals: 0, clipping: .shadows,
                   help: String(localized: "Sets the darkest point. Hold Option to see clipped shadows.", bundle: L10n.bundle))
        }
    }

    private var colorControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("White Balance").frame(minWidth: Self.labelWidth, alignment: .leading)
                    .help("Auto balances the average color. Custom follows Temperature and Tint.")
                Picker("White Balance", selection: Binding(get: { raw.whiteBalance }, set: setWhiteBalance)) {
                    ForEach(CameraRawWhiteBalance.allCases, id: \.self) { Text(L10n.text($0.rawValue)).tag($0) }
                }
                .labelsHidden()
                .help("Auto balances the average color. Custom follows Temperature and Tint.")
                Button {
                    session.filterEdit?.samplesWhiteBalance.toggle()
                    session.brushRevision += 1
                } label: {
                    Image(systemName: "eyedropper")
                }
                .buttonStyle(.borderless)
                .tint(session.filterEdit?.samplesWhiteBalance == true ? Color.accentColor : Color.secondary)
                .help("Click a pixel that should be neutral.")
                .accessibilityLabel(String(localized: "White Balance Selector", bundle: L10n.bundle))
            }
            if session.filterEdit?.samplesWhiteBalance == true {
                Text("Click the original layer. Click the eyedropper again to stop.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            slider(String(localized: "Temperature", bundle: L10n.bundle), \.temperature, range: CameraRawSettings.toneRange, decimals: 0, clipping: nil,
                   track: .temperature, help: String(localized: "Shifts the picture from blue to yellow.", bundle: L10n.bundle))
            slider(String(localized: "Tint", bundle: L10n.bundle), \.tint, range: CameraRawSettings.toneRange, decimals: 0, clipping: nil,
                   track: .tint, help: String(localized: "Shifts the picture from green to mauve.", bundle: L10n.bundle))
            slider(String(localized: "Vibrance", bundle: L10n.bundle), \.vibrance, range: CameraRawSettings.toneRange, decimals: 0, clipping: nil,
                   track: .chroma, help: String(localized: "Strengthens quiet colors more than colors that are already strong, and protects skin tones.", bundle: L10n.bundle))
            slider(String(localized: "Saturation", bundle: L10n.bundle), \.saturation, range: CameraRawSettings.toneRange, decimals: 0, clipping: nil,
                   track: .chroma, help: String(localized: "Strengthens or weakens every color by the same amount.", bundle: L10n.bundle))
        }
    }

    private var effectsControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            slider(String(localized: "Texture", bundle: L10n.bundle), \.texture, range: CameraRawSettings.toneRange, decimals: 0, clipping: nil,
                   help: String(localized: "Adds or softens small detail.", bundle: L10n.bundle))
            slider(String(localized: "Clarity", bundle: L10n.bundle), \.clarity, range: CameraRawSettings.toneRange, decimals: 0, clipping: nil,
                   help: String(localized: "Adds or softens contrast along broader shapes.", bundle: L10n.bundle))
            slider(String(localized: "Dehaze", bundle: L10n.bundle), \.dehaze, range: CameraRawSettings.toneRange, decimals: 0, clipping: nil,
                   help: String(localized: "Clears haze when raised, and adds haze when lowered.", bundle: L10n.bundle))
            Text("Glow").font(.subheadline)
            slider(String(localized: "Glow", bundle: L10n.bundle), \.glow, range: CameraRawSettings.unitRange, decimals: 0, clipping: nil,
                   help: String(localized: "Spreads a glow from the bright areas.", bundle: L10n.bundle))
            Picker("Style", selection: Binding(get: { raw.glowStyle }, set: { style in update { $0.cameraRaw.glowStyle = style } })) {
                ForEach(CameraRawGlowStyle.allCases, id: \.self) { Text(L10n.text($0.rawValue)).tag($0) }
            }
            .help("Diffusion is soft and wide, Bloom is tighter, and Halation is a red fringe.")
            VStack(alignment: .leading, spacing: 8) {
                slider(String(localized: "Range", bundle: L10n.bundle), \.glowRange, range: CameraRawSettings.toneRange, decimals: 0, clipping: nil,
                       help: String(localized: "Chooses how bright an area must be to glow. Has no effect until Glow is raised.", bundle: L10n.bundle))
                slider(String(localized: "Spread", bundle: L10n.bundle), \.glowSpread, range: CameraRawSettings.toneRange, decimals: 0, clipping: nil,
                       help: String(localized: "Sets how far the glow reaches. Has no effect until Glow is raised.", bundle: L10n.bundle))
                slider(String(localized: "Warmth", bundle: L10n.bundle), \.glowWarmth, range: CameraRawSettings.toneRange, decimals: 0, clipping: nil,
                       help: String(localized: "Shifts the glow from cool to warm. Halation stays red. Has no effect until Glow is raised.", bundle: L10n.bundle))
            }
            .padding(.leading, 16)
            Text("Vignette").font(.subheadline)
            slider(String(localized: "Amount", bundle: L10n.bundle), \.vignetteAmount, range: CameraRawSettings.toneRange, decimals: 0, clipping: nil,
                   help: String(localized: "Darkens or lightens the edges. The center does not change.", bundle: L10n.bundle))
            Picker("Style", selection: Binding(get: { raw.vignetteStyle }, set: { style in update { $0.cameraRaw.vignetteStyle = style } })) {
                ForEach(CameraRawVignetteStyle.allCases, id: \.self) { Text(L10n.text($0.rawValue)).tag($0) }
            }
            .help("Highlight Priority protects bright edges. Color Priority also reduces color. Paint Overlay covers the edges evenly.")
            VStack(alignment: .leading, spacing: 8) {
                slider(String(localized: "Midpoint", bundle: L10n.bundle), \.vignetteMidpoint, range: CameraRawSettings.unitRange, decimals: 0, clipping: nil,
                       reset: 50, help: String(localized: "Sets where the vignette begins, from the center outward.", bundle: L10n.bundle))
                slider(String(localized: "Roundness", bundle: L10n.bundle), \.vignetteRoundness, range: CameraRawSettings.toneRange, decimals: 0, clipping: nil,
                       help: String(localized: "Makes the vignette rounder or more square.", bundle: L10n.bundle))
                slider(String(localized: "Feather", bundle: L10n.bundle), \.vignetteFeather, range: CameraRawSettings.unitRange, decimals: 0, clipping: nil,
                       reset: 50, help: String(localized: "Softens the edge of the vignette.", bundle: L10n.bundle))
                slider(String(localized: "Highlights", bundle: L10n.bundle), \.vignetteHighlights, range: CameraRawSettings.unitRange, decimals: 0, clipping: nil,
                       help: String(localized: "Protects bright pixels while a dark vignette is applied. Used by Highlight Priority.", bundle: L10n.bundle))
            }
            .padding(.leading, 16)
            Text("Grain").font(.subheadline)
            slider(String(localized: "Amount", bundle: L10n.bundle), \.grainAmount, range: CameraRawSettings.unitRange, decimals: 0, clipping: nil,
                   help: String(localized: "Adds film grain, strongest in the middle tones.", bundle: L10n.bundle))
            slider(String(localized: "Size", bundle: L10n.bundle), \.grainSize, range: CameraRawSettings.unitRange, decimals: 0, clipping: nil,
                   reset: 25, help: String(localized: "Makes the grain coarser or finer.", bundle: L10n.bundle))
            slider(String(localized: "Roughness", bundle: L10n.bundle), \.grainRoughness, range: CameraRawSettings.unitRange, decimals: 0, clipping: nil,
                   reset: 50, help: String(localized: "Makes the grain smoother or more uneven.", bundle: L10n.bundle))
        }
    }

    private func eye(shown: Bool, name: String, group: PanelEye) -> some View {
        Button {
            switch group {
            case .light: session.filterEdit?.showsCameraRawLight.toggle()
            case .color: session.filterEdit?.showsCameraRawColor.toggle()
            case .effects: session.filterEdit?.showsCameraRawEffects.toggle()
            case .curve: session.filterEdit?.showsCameraRawCurve.toggle()
            case .mixer: session.filterEdit?.showsCameraRawMixer.toggle()
            case .grading: session.filterEdit?.showsCameraRawGrading.toggle()
            case .detail: session.filterEdit?.showsCameraRawDetail.toggle()
            case .optics: session.filterEdit?.showsCameraRawOptics.toggle()
            case .geometry: session.filterEdit?.showsCameraRawGeometry.toggle()
            case .calibration: session.filterEdit?.showsCameraRawCalibration.toggle()
            }
            if let edit = session.filterEdit { session.updateFilter(edit.settings, preview: edit.preview) }
        } label: {
            Image(systemName: shown ? "eye" : "eye.slash")
        }
        .buttonStyle(.borderless)
        .help(shown ? String(localized: "Hide \(name) in the preview", bundle: L10n.bundle) : String(localized: "Show \(name) in the preview", bundle: L10n.bundle))
        .accessibilityLabel(shown ? String(localized: "Hide \(name)", bundle: L10n.bundle) : String(localized: "Show \(name)", bundle: L10n.bundle))
    }

    /// Puts an adjusted section back to its defaults.
    private func resetButton(_ group: CameraRawGroup) -> some View {
        Button { session.resetCameraRaw(group) } label: {
            Image(systemName: "arrow.counterclockwise")
        }
        .buttonStyle(.borderless)
        .disabled(session.filterEdit?.committing == true)
        .help(String(localized: "Reset \(L10n.text(group.rawValue)) to its defaults", bundle: L10n.bundle))
        .accessibilityLabel(String(localized: "Reset \(L10n.text(group.rawValue))", bundle: L10n.bundle))
    }

    private func slider(_ title: String, _ key: WritableKeyPath<CameraRawSettings, Double>, range: ClosedRange<Double>,
                        decimals: Int, clipping: CameraRawClipping?, track: CameraRawSliderTrack = .plain,
                        reset resetValue: Double = 0, help: String) -> some View {
        let step = pow(10, Double(decimals))
        return HStack(spacing: 10) {
            Text(L10n.text(title))
                .frame(minWidth: Self.labelWidth, alignment: .leading)
                .help(L10n.text(help))
                .onTapGesture(count: 2) { reset(key, to: resetValue) }
                .scrubbable(sensitivity: 1 / step,
                            value: Binding(get: { raw[keyPath: key] }, set: { assign(key, $0, clipping: nil) }),
                            range: range)
            CameraRawSlider(value: raw[keyPath: key], range: range, track: track, help: help,
                            onChange: { rawValue in assign(key, (rawValue * step).rounded() / step, clipping: clipping) },
                            onReset: { reset(key, to: resetValue) })
            TextField(L10n.text(title), value: Binding(get: { raw[keyPath: key] }, set: { assign(key, $0, clipping: nil) }),
                      format: .number.precision(.fractionLength(0...decimals)))
                .frame(width: 56).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                .help(L10n.text(help))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text(title))
    }

    private func setWhiteBalance(_ mode: CameraRawWhiteBalance) {
        if mode == .auto {
            Task { await session.applyCameraRawAutoWhiteBalance() }
            return
        }
        update { settings in
            settings.cameraRaw.whiteBalance = mode
        }
    }

    private func assign(_ key: WritableKeyPath<CameraRawSettings, Double>, _ newValue: Double, clipping: CameraRawClipping?) {
        let showClipping = clipping != nil && NSEvent.modifierFlags.contains(.option)
        session.filterEdit?.cameraRawClipping = showClipping ? clipping : nil
        update { settings in
            settings.cameraRaw[keyPath: key] = newValue
            if key == \.temperature || key == \.tint { settings.cameraRaw.whiteBalance = .custom }
        }
    }

    private func reset(_ key: WritableKeyPath<CameraRawSettings, Double>, to resetValue: Double) {
        session.filterEdit?.cameraRawClipping = nil
        assign(key, resetValue, clipping: nil)
    }

    private enum PanelEye { case light, color, effects, curve, mixer, grading, detail, optics, geometry, calibration }

    private func update(_ change: (inout FilterSettings) -> Void) {
        var value = settings
        change(&value)
        session.updateFilter(value, preview: session.filterEdit?.preview ?? true)
    }

    private func installOptionMonitor() {
        removeOptionMonitor()
        optionMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            if !event.modifierFlags.contains(.option) {
                let edit = session.filterEdit
                if edit?.cameraRawClipping != nil || edit?.cameraRawSharpenMask == true {
                    edit?.cameraRawClipping = nil
                    edit?.cameraRawSharpenMask = false
                    if let edit { session.updateFilter(edit.settings, preview: edit.preview) }
                }
            }
            return event
        }
    }

    private func removeOptionMonitor() {
        if let optionMonitor { NSEvent.removeMonitor(optionMonitor) }
        optionMonitor = nil
    }

    static let labelWidth: CGFloat = 96

    private enum Section: String, CaseIterable, Identifiable {
        case light = "Light"
        case color = "Color"
        case colorGrading = "Color Grading"
        case effects = "Effects"
        case curve = "Curve"
        case colorMixer = "Color Mixer"
        case detail = "Detail"
        case optics = "Optics"
        case geometry = "Geometry"
        case calibration = "Calibration"
        var id: String { rawValue }
        var group: CameraRawGroup {
            switch self {
            case .light: return .light
            case .color: return .color
            case .colorGrading: return .grading
            case .effects: return .effects
            case .curve: return .curve
            case .colorMixer: return .mixer
            case .detail: return .detail
            case .optics: return .optics
            case .geometry: return .geometry
            case .calibration: return .calibration
            }
        }
    }
}
