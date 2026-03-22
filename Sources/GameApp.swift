import SwiftUI
import AppKit

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - App entry + menus
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@main
struct Game2048App: App {
    @StateObject private var model = GameModel()

    init() {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.applicationIconImage = Self.makeIcon()
        }
    }

    var body: some Scene {
        WindowGroup("2048") {
            ContentView(model: model)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 520, height: 680)
        .commands {
            // File > New Game
            CommandGroup(replacing: .newItem) {
                Button("New Game") { model.newGame() }
                    .keyboardShortcut("n")
            }
            // Game menu
            CommandMenu("Game") {
                Picker("Grid Size", selection: Binding(
                    get: { model.N },
                    set: { model.setGridSize($0) }
                )) {
                    Text("4×4 Classic").tag(4)
                    Text("5×5").tag(5)
                    Text("6×6").tag(6)
                }
                Divider()
                Toggle("Timed Mode", isOn: Binding(
                    get: { model.timedMode },
                    set: { model.setTimedMode($0) }
                ))
                if model.timedMode {
                    Picker("Time Limit", selection: Binding(
                        get: { model.timerDuration },
                        set: { model.setTimerDuration($0) }
                    )) {
                        Text("1 min").tag(60)
                        Text("3 min").tag(180)
                        Text("5 min").tag(300)
                    }
                }
            }
        }

        Settings {
            PreferencesView(model: model)
        }
    }

    // ── Programmatic app icon ──────────────────────────────────────
    static func makeIcon() -> NSImage {
        let s: CGFloat = 512
        let img = NSImage(size: NSSize(width: s, height: s))
        img.lockFocus()
        let rect = NSRect(x: 30, y: 30, width: s - 60, height: s - 60)
        let bg = NSBezierPath(roundedRect: rect, xRadius: 80, yRadius: 80)
        NSGradient(colors: [
            NSColor(red: 0.96, green: 0.80, blue: 0.25, alpha: 1),
            NSColor(red: 0.92, green: 0.72, blue: 0.15, alpha: 1)
        ])!.draw(in: bg, angle: -45)
        let font = NSFont.systemFont(ofSize: 130, weight: .heavy)
        let shadow = NSShadow(); shadow.shadowColor = .black.withAlphaComponent(0.25)
        shadow.shadowOffset = NSSize(width: 0, height: -5); shadow.shadowBlurRadius = 10
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white, .shadow: shadow]
        let str = NSAttributedString(string: "2048", attributes: attrs)
        let ts = str.size()
        str.draw(at: NSPoint(x: (s - ts.width) / 2, y: (s - ts.height) / 2))
        img.unlockFocus()
        return img
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Dark / Light theme
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
struct Theme {
    let dark: Bool
    init(_ cs: ColorScheme) { dark = cs == .dark }

    var windowBg:   Color { dark ? Color(red: 0.11, green: 0.11, blue: 0.13) : Color(red: 0.98, green: 0.97, blue: 0.94) }
    var boardBg:    Color { dark ? Color(red: 0.20, green: 0.20, blue: 0.23) : Color(red: 0.73, green: 0.68, blue: 0.63) }
    var cellBg:     Color { dark ? Color(white: 0.28) : Color(red: 0.93, green: 0.89, blue: 0.85).opacity(0.35) }
    var titleColor: Color { dark ? Color(red: 0.90, green: 0.86, blue: 0.78) : Color(red: 0.47, green: 0.43, blue: 0.40) }
    var scoreBoxBg: Color { dark ? Color(red: 0.24, green: 0.24, blue: 0.28) : Color(red: 0.73, green: 0.68, blue: 0.63) }
    var buttonBg:   Color { dark ? Color(red: 0.38, green: 0.35, blue: 0.30) : Color(red: 0.56, green: 0.48, blue: 0.40) }
    var overlayBg:  Color { dark ? Color.black.opacity(0.65) : Color(red: 0.93, green: 0.89, blue: 0.85).opacity(0.72) }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Tile colour palette (same in both modes — they pop against dark bg)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
private let TC: [Int: (bg: Color, fg: Color)] = [
    2:    (.init(red: 0.933, green: 0.894, blue: 0.855), .init(red: 0.47, green: 0.43, blue: 0.40)),
    4:    (.init(red: 0.929, green: 0.878, blue: 0.784), .init(red: 0.47, green: 0.43, blue: 0.40)),
    8:    (.init(red: 0.949, green: 0.694, blue: 0.475), .white),
    16:   (.init(red: 0.961, green: 0.584, blue: 0.388), .white),
    32:   (.init(red: 0.965, green: 0.486, blue: 0.373), .white),
    64:   (.init(red: 0.965, green: 0.369, blue: 0.231), .white),
    128:  (.init(red: 0.929, green: 0.812, blue: 0.447), .white),
    256:  (.init(red: 0.929, green: 0.800, blue: 0.380), .white),
    512:  (.init(red: 0.929, green: 0.784, blue: 0.314), .white),
    1024: (.init(red: 0.929, green: 0.769, blue: 0.247), .white),
    2048: (.init(red: 0.929, green: 0.757, blue: 0.180), .white),
    4096: (.init(red: 0.38, green: 0.18, blue: 0.56), .white),
    8192: (.init(red: 0.20, green: 0.15, blue: 0.55), .white),
]
private let fallBg = Color(red: 0.24, green: 0.23, blue: 0.20)
private func tileBg(_ v: Int) -> Color { TC[v]?.bg ?? fallBg }
private func tileFg(_ v: Int) -> Color { TC[v]?.fg ?? .white }
private func tileFontFactor(_ v: Int) -> CGFloat {
    switch v { case ..<100: return 0.40; case ..<1000: return 0.33; default: return 0.25 }
}

// Glow: higher-value tiles glow stronger, moving tiles glow more
private func tileGlow(_ v: Int, moving: Bool) -> (color: Color, radius: CGFloat) {
    let base: (Double, CGFloat) = switch v {
        case ..<8:    (0, 0)
        case ..<64:   (0.30, 6)
        case ..<512:  (0.50, 12)
        default:      (0.70, 18)
    }
    let boost: Double  = moving ? 0.3 : 0
    let rBoost: CGFloat = moving ? 10 : 0
    return (tileBg(v).opacity(base.0 + boost), base.1 + rBoost)
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - ContentView
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
struct ContentView: View {
    @ObservedObject var model: GameModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let t = Theme(colorScheme)
        VStack(spacing: 0) {
            HeaderView(model: model, theme: t)
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 8)

            if model.timedMode {
                TimerBarView(remaining: model.timeRemaining, total: model.timerDuration)
                    .padding(.horizontal, 20).padding(.bottom, 8)
            }

            // Subtitle
            HStack {
                Text(subtitleText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(t.titleColor.opacity(0.7))
                Spacer()
                Button("New Game") { model.newGame() }
                    .buttonStyle(PillButton(bg: t.buttonBg))
            }
            .padding(.horizontal, 20).padding(.bottom, 12)

            BoardContainerView(model: model, theme: t)
                .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .frame(minWidth: 380, idealWidth: 520, minHeight: 500, idealHeight: 680)
        .background(t.windowBg)
    }

    private var subtitleText: String {
        let grid = "\(model.N)×\(model.N)"
        let mode = model.timedMode ? " Timed" : ""
        return "\(grid)\(mode) — join tiles to reach 2048!"
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Header
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
struct HeaderView: View {
    @ObservedObject var model: GameModel
    let theme: Theme

    var body: some View {
        HStack(alignment: .top) {
            Text("2048")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(theme.titleColor)
            Spacer()
            HStack(spacing: 8) {
                ScoreBox(label: "SCORE", value: model.score, deltas: model.scoreDeltas, bg: theme.scoreBoxBg)
                ScoreBox(label: "BEST",  value: model.best,  deltas: [],                bg: theme.scoreBoxBg)
            }
        }
    }
}

struct ScoreBox: View {
    let label: String; let value: Int; let deltas: [ScoreDelta]; let bg: Color
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 2) {
                Text(label).font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7)).tracking(1)
                Text("\(value)").font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.spring(response: 0.3), value: value)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 6).fill(bg))
            ForEach(deltas) { d in FloatingDeltaView(value: d.value) }
        }
    }
}

struct FloatingDeltaView: View {
    let value: Int
    @State private var off: CGFloat = 0; @State private var op: Double = 1
    var body: some View {
        Text("+\(value)").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
            .offset(y: off).opacity(op)
            .onAppear { withAnimation(.easeOut(duration: 0.75)) { off = -32; op = 0 } }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Timer bar
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
struct TimerBarView: View {
    let remaining: Int; let total: Int
    var progress: CGFloat { total > 0 ? CGFloat(remaining) / CGFloat(total) : 0 }
    var barColor: Color { progress > 0.5 ? .green : progress > 0.2 ? .yellow : .red }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3))
                    RoundedRectangle(cornerRadius: 4).fill(barColor)
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 1), value: remaining)
                }
            }.frame(height: 8)
            Text(timeString).font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
    private var timeString: String {
        let m = remaining / 60; let s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Board
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
struct BoardContainerView: View {
    @ObservedObject var model: GameModel; let theme: Theme
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            BoardView(model: model, theme: theme, side: side)
                .frame(width: side, height: side)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }.aspectRatio(1, contentMode: .fit)
    }
}

struct BoardView: View {
    @ObservedObject var model: GameModel; let theme: Theme; let side: CGFloat
    private var N: Int { model.N }
    private var gap: CGFloat { N <= 4 ? 10 : N <= 5 ? 8 : 6 }
    private var tileS: CGFloat { (side - gap * CGFloat(N + 1)) / CGFloat(N) }

    private func pos(_ r: Int, _ c: Int) -> CGPoint {
        CGPoint(x: gap + CGFloat(c) * (tileS + gap) + tileS / 2,
                y: gap + CGFloat(r) * (tileS + gap) + tileS / 2)
    }

    // Spring parameters scaled by animation intensity
    private var moveDamping: CGFloat { max(0.30, 0.74 * CGFloat(1.5 - model.animationIntensity * 0.5)) }
    private var moveResponse: CGFloat { 0.24 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(theme.boardBg)

            // Empty cells
            ForEach(Array(0..<N), id: \.self) { r in
                ForEach(Array(0..<N), id: \.self) { c in
                    RoundedRectangle(cornerRadius: 7).fill(theme.cellBg)
                        .frame(width: tileS, height: tileS).position(pos(r, c))
                }
            }

            // Tiles
            ForEach(model.tiles.sorted { !$0.isRemoving && $1.isRemoving }) { tile in
                TileView(tile: tile, size: tileS, intensity: model.animationIntensity)
                    .position(pos(tile.row, tile.col))
                    .animation(.spring(response: moveResponse, dampingFraction: moveDamping, blendDuration: 0), value: tile.row)
                    .animation(.spring(response: moveResponse, dampingFraction: moveDamping, blendDuration: 0), value: tile.col)
                    .animation(.easeOut(duration: 0.18), value: tile.isRemoving)
                    .zIndex(tile.isRemoving ? 0 : tile.mergeCount > 0 ? 2 : 1)
            }

            // Ripple shockwaves (128+ merges)
            ForEach(model.ripples) { ripple in
                RippleView(color: tileBg(ripple.value), tileSize: tileS)
                    .position(pos(ripple.row, ripple.col))
                    .zIndex(50)
                    .allowsHitTesting(false)
            }

            // Overlay — zIndex 100 so it is always above tiles AND ripples
            if model.isGameOver || model.isWon {
                OverlayView(model: model, theme: theme)
                    .zIndex(100)
                    .transition(.opacity.animation(.easeIn(duration: 0.3)))
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Tile view — glow + spring physics
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
struct TileView: View {
    let tile: Tile; let size: CGFloat; let intensity: Double
    @State private var scale: CGFloat = 1.0

    private var mergeScale:   CGFloat { 1.0 + 0.26 * CGFloat(intensity) }
    private var mergeDamping: CGFloat { max(0.25, 0.48 * CGFloat(1.4 - intensity * 0.4)) }
    private var glow: (color: Color, radius: CGFloat) { tileGlow(tile.value, moving: tile.isMoving) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7).fill(tileBg(tile.value))
            RoundedRectangle(cornerRadius: 7).fill(
                LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .center)
            )
            Text("\(tile.value)")
                .font(.system(size: size * tileFontFactor(tile.value), weight: .bold, design: .rounded))
                .foregroundColor(tileFg(tile.value))
                .minimumScaleFactor(0.4)
        }
        .frame(width: size, height: size)
        .scaleEffect(scale)
        // Dynamic shadow (elevation on merge pop)
        .shadow(color: .black.opacity(0.15 + max(0, scale - 1) * 0.35),
                radius: 5 + max(0, scale - 1) * 14, x: 0, y: 3 + max(0, scale - 1) * 7)
        // Colour glow (trail effect)
        .shadow(color: glow.color, radius: glow.radius)
        .opacity(tile.isRemoving ? 0 : 1)
        // ── Spawn animation ────────────────────────────────────────
        .onAppear {
            if tile.isNew {
                scale = 0.05
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { scale = 1 }
            }
        }
        // ── Merge bounce ───────────────────────────────────────────
        .onChange(of: tile.mergeCount) { _ in
            withAnimation(.spring(response: 0.13, dampingFraction: 0.30)) { scale = mergeScale }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                withAnimation(.spring(response: 0.30, dampingFraction: mergeDamping)) { scale = 1 }
            }
        }
        // Glow transition
        .animation(.easeInOut(duration: 0.25), value: tile.isMoving)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Overlay
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
struct OverlayView: View {
    @ObservedObject var model: GameModel; let theme: Theme
    var body: some View {
        ZStack {
            (model.isWon
                ? Color(red: 0.929, green: 0.757, blue: 0.180).opacity(0.55)
                : theme.overlayBg)
            VStack(spacing: 16) {
                Text(model.isWon ? "You Win!" : "Game Over")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(model.isWon ? .white : theme.titleColor)
                Button("Try Again") { model.newGame() }
                    .buttonStyle(PillButton(bg: theme.buttonBg))
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Ripple shockwave (128+ merges)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
struct RippleView: View {
    let color: Color; let tileSize: CGFloat
    var body: some View {
        ZStack {
            RippleRing(color: color, tileSize: tileSize, delay: 0.00)
            RippleRing(color: color, tileSize: tileSize, delay: 0.16)
            RippleRing(color: color, tileSize: tileSize, delay: 0.32)
        }
    }
}

struct RippleRing: View {
    let color: Color; let tileSize: CGFloat; let delay: Double
    @State private var scale: CGFloat = 0.55
    @State private var opacity: Double = 0.90

    var body: some View {
        Circle()
            .stroke(color, lineWidth: max(1.5, tileSize * 0.05))
            .frame(width: tileSize, height: tileSize)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: 0.70)) {
                        scale   = 3.2
                        opacity = 0
                    }
                }
            }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Preferences (⌘,)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
struct PreferencesView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        TabView {
            Form {
                Section("Game") {
                    Picker("Grid Size", selection: Binding(get: { model.N }, set: { model.setGridSize($0) })) {
                        Text("4×4 Classic").tag(4)
                        Text("5×5").tag(5)
                        Text("6×6").tag(6)
                    }
                    Toggle("Timed Mode", isOn: Binding(get: { model.timedMode }, set: { model.setTimedMode($0) }))
                    if model.timedMode {
                        Picker("Time Limit", selection: Binding(get: { model.timerDuration }, set: { model.setTimerDuration($0) })) {
                            Text("1 minute").tag(60)
                            Text("3 minutes").tag(180)
                            Text("5 minutes").tag(300)
                        }
                    }
                }
                Section("Animation") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Physics Intensity")
                        Slider(value: Binding(get: { model.animationIntensity }, set: { model.setAnimationIntensity($0) }),
                               in: 0.2...2.0, step: 0.1)
                        Text(intensityLabel).font(.caption).foregroundColor(.secondary)
                    }
                }
                Section {
                    Button("Reset All High Scores", role: .destructive) { model.resetBestScores() }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 380, height: 360)
    }

    private var intensityLabel: String {
        switch model.animationIntensity {
        case ..<0.5: return "Minimal — barely any animation"
        case ..<1.0: return "Subtle — gentle animations"
        case ..<1.5: return "Normal — default physics feel"
        default:     return "Extra bouncy — maximum spring!"
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Button style
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
struct PillButton: ButtonStyle {
    let bg: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 16).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 6).fill(bg.opacity(configuration.isPressed ? 0.7 : 1)))
    }
}
