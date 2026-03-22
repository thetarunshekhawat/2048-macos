import Foundation
import AppKit

// MARK: - Direction
enum Direction { case up, down, left, right }

// MARK: - Tile
struct Tile: Identifiable {
    let id: UUID
    var value: Int
    var row: Int
    var col: Int
    var isNew:      Bool = false
    var mergeCount: Int  = 0
    var isRemoving: Bool = false
    var isMoving:   Bool = false

    init(value: Int, row: Int, col: Int, id: UUID = UUID(), isNew: Bool = false) {
        self.id = id; self.value = value; self.row = row; self.col = col; self.isNew = isNew
    }
}

struct ScoreDelta: Identifiable { let id = UUID(); let value: Int }

// MARK: - Ripple event (value >= 128 merges)
struct RippleEvent: Identifiable { let id = UUID(); let row: Int; let col: Int; let value: Int }

// MARK: - Game Model
class GameModel: ObservableObject {
    // ── Published game state ───────────────────────────────────────
    @Published var tiles:        [Tile]       = []
    @Published var score:        Int          = 0
    @Published var best:         Int          = 0
    @Published var isGameOver:   Bool         = false
    @Published var isWon:        Bool         = false
    @Published var scoreDeltas:  [ScoreDelta] = []
    @Published var ripples:      [RippleEvent] = []
    @Published var timeRemaining: Int         = 0

    // ── Published settings ─────────────────────────────────────────
    @Published private(set) var N: Int = 4
    @Published var timedMode:          Bool   = false
    @Published var timerDuration:      Int    = 180
    @Published var animationIntensity: Double = 1.0

    // ── Private ────────────────────────────────────────────────────
    private var grid:        [[UUID?]] = []
    private var keyMonitor:  Any?
    private var gameTimer:   Timer?
    private var moveGen = 0                  // generation counter to cancel stale callbacks

    // ── Init ───────────────────────────────────────────────────────
    init() {
        let gs = UserDefaults.standard.integer(forKey: "gridSize")
        N = (4...6).contains(gs) ? gs : 4
        timedMode = UserDefaults.standard.bool(forKey: "timedMode")
        let td = UserDefaults.standard.integer(forKey: "timerDuration")
        timerDuration = td > 0 ? td : 180
        let ai = UserDefaults.standard.double(forKey: "animationIntensity")
        animationIntensity = ai > 0 ? ai : 1.0
        loadBest()
        newGame()
        installKeyboardMonitor()
    }
    deinit {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        gameTimer?.invalidate()
    }

    // ── Keyboard ───────────────────────────────────────────────────
    private func installKeyboardMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) { return event }
            switch event.keyCode {
            case 123: self.move(.left);  return nil
            case 124: self.move(.right); return nil
            case 125: self.move(.down);  return nil
            case 126: self.move(.up);    return nil
            case 0:   self.move(.left);  return nil
            case 2:   self.move(.right); return nil
            case 1:   self.move(.down);  return nil
            case 13:  self.move(.up);    return nil
            default:  return event
            }
        }
    }

    // ── Settings persistence ───────────────────────────────────────
    func setGridSize(_ s: Int) {
        N = s; UserDefaults.standard.set(s, forKey: "gridSize"); loadBest(); newGame()
    }
    func setTimedMode(_ on: Bool) {
        timedMode = on; UserDefaults.standard.set(on, forKey: "timedMode")
        on ? startTimer() : stopTimer()
    }
    func setTimerDuration(_ d: Int) {
        timerDuration = d; UserDefaults.standard.set(d, forKey: "timerDuration")
    }
    func setAnimationIntensity(_ v: Double) {
        animationIntensity = v; UserDefaults.standard.set(v, forKey: "animationIntensity")
    }
    func resetBestScores() {
        for s in 4...6 { UserDefaults.standard.removeObject(forKey: "best\(s)") }
        best = 0
    }
    private func loadBest() { best = UserDefaults.standard.integer(forKey: "best\(N)") }
    private func saveBest() {
        if score > best { best = score; UserDefaults.standard.set(best, forKey: "best\(N)") }
    }

    // ── Timer ──────────────────────────────────────────────────────
    private func startTimer() {
        gameTimer?.invalidate()
        timeRemaining = timerDuration
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.timedMode, !self.isGameOver else { self?.gameTimer?.invalidate(); return }
                if self.timeRemaining > 0 { self.timeRemaining -= 1 }
                else { self.gameTimer?.invalidate(); self.isGameOver = true }
            }
        }
    }
    private func stopTimer() { gameTimer?.invalidate(); gameTimer = nil }

    // ── New game ───────────────────────────────────────────────────
    func newGame() {
        moveGen += 1
        tiles = []; grid = Array(repeating: Array(repeating: nil, count: N), count: N)
        score = 0; isGameOver = false; isWon = false; scoreDeltas = []; ripples = []
        loadBest(); spawn(); spawn()
        if timedMode { startTimer() }
    }

    // ── Spawn ──────────────────────────────────────────────────────
    @discardableResult func spawn() -> Bool {
        var empty: [(Int, Int)] = []
        for r in 0..<N { for c in 0..<N { if grid[r][c] == nil { empty.append((r, c)) } } }
        guard let (r, c) = empty.randomElement() else { return false }
        let t = Tile(value: Double.random(in: 0..<1) < 0.9 ? 2 : 4, row: r, col: c, isNew: true)
        grid[r][c] = t.id; tiles.append(t)
        let tid = t.id; let gen = moveGen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.moveGen == gen else { return }
            if let i = self.tiles.firstIndex(where: { $0.id == tid }) { self.tiles[i].isNew = false }
        }
        return true
    }

    // ── Move ───────────────────────────────────────────────────────
    func move(_ dir: Direction) {
        guard !isGameOver else { return }

        var moved = false; var scoreDelta = 0
        var mergePairs: [(UUID, UUID)] = []

        if dir == .left || dir == .right {
            for r in 0..<N {
                var line = (0..<N).compactMap { c in grid[r][c] }
                if dir == .right { line.reverse() }
                let (res, pairs, _) = slide(line, scoreDelta: &scoreDelta)
                mergePairs += pairs
                let full = pad(res); let fin = dir == .right ? full.reversed() : full
                for c in 0..<N {
                    if grid[r][c] != fin[c] { moved = true }
                    grid[r][c] = fin[c]
                    if let id = fin[c], let i = idx(id) { tiles[i].row = r; tiles[i].col = c }
                }
            }
        } else {
            for c in 0..<N {
                var line = (0..<N).compactMap { r in grid[r][c] }
                if dir == .down { line.reverse() }
                let (res, pairs, _) = slide(line, scoreDelta: &scoreDelta)
                mergePairs += pairs
                let full = pad(res); let fin = dir == .down ? full.reversed() : full
                for r in 0..<N {
                    if grid[r][c] != fin[r] { moved = true }
                    grid[r][c] = fin[r]
                    if let id = fin[r], let i = idx(id) { tiles[i].row = r; tiles[i].col = c }
                }
            }
        }

        guard moved || !mergePairs.isEmpty else { return }

        // Glow trail
        for i in tiles.indices where !tiles[i].isRemoving { tiles[i].isMoving = true }
        let gen = moveGen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, self.moveGen == gen else { return }
            for i in self.tiles.indices { self.tiles[i].isMoving = false }
        }

        // Score
        if scoreDelta > 0 {
            score += scoreDelta; saveBest()
            let d = ScoreDelta(value: scoreDelta); scoreDeltas.append(d)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                self?.scoreDeltas.removeAll { $0.id == d.id }
            }
        }

        // Casualties + ripple for large merges
        for (cid, sid) in mergePairs {
            guard let ci = idx(cid), let si = idx(sid) else { continue }
            tiles[ci].row = tiles[si].row; tiles[ci].col = tiles[si].col; tiles[ci].isRemoving = true
            // Ripple effect for 128+
            if tiles[si].value >= 128 {
                let ev = RippleEvent(row: tiles[si].row, col: tiles[si].col, value: tiles[si].value)
                ripples.append(ev)
                let eid = ev.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                    self?.ripples.removeAll { $0.id == eid }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
            guard let self, self.moveGen == gen else { return }
            self.tiles.removeAll { $0.isRemoving }
        }

        // Spawn + checks
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
            guard let self, self.moveGen == gen else { return }
            self.spawn()
            if !self.isWon, self.tiles.contains(where: { $0.value == 2048 }) { self.isWon = true }
            if !self.isWon, self.noMovesLeft() { self.isGameOver = true; self.stopTimer() }
        }
    }

    // ── Helpers ────────────────────────────────────────────────────
    private func slide(_ ids: [UUID], scoreDelta: inout Int) -> ([UUID], [(UUID, UUID)], Int) {
        var arr = ids; var pairs = [(UUID, UUID)](); var gain = 0; var i = 0
        while i < arr.count - 1 {
            let a = arr[i], b = arr[i+1]
            guard let ai = idx(a), let bi = idx(b), tiles[ai].value == tiles[bi].value else { i += 1; continue }
            tiles[ai].value *= 2; tiles[ai].mergeCount += 1
            gain += tiles[ai].value; pairs.append((b, a)); arr.remove(at: i+1); i += 1
        }
        scoreDelta += gain; return (arr, pairs, gain)
    }
    private func pad(_ a: [UUID]) -> [UUID?] {
        var r: [UUID?] = a.map { $0 }; while r.count < N { r.append(nil) }; return r
    }
    private func idx(_ id: UUID) -> Int? { tiles.firstIndex { $0.id == id } }
    private func noMovesLeft() -> Bool {
        for r in 0..<N { for c in 0..<N {
            if grid[r][c] == nil { return false }
            let v = tiles.first { $0.id == grid[r][c] }?.value ?? 0
            if c < N-1, let nv = tiles.first(where: { $0.id == grid[r][c+1] })?.value, v == nv { return false }
            if r < N-1, let nv = tiles.first(where: { $0.id == grid[r+1][c] })?.value, v == nv { return false }
        }}
        return true
    }
}
