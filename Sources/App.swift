import SwiftUI
import AVFoundation

@main
struct SalatTasbihApp: App {
    @StateObject var store = Store()
    @AppStorage("appearance") var appearance = 0
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .preferredColorScheme(appearance == 1 ? .light : appearance == 2 ? .dark : nil)
                .frame(minWidth: 860, minHeight: 640)
        }
    }
}

// MARK: Data + streaks
struct Model: Codable {
    var opened: Set<String> = []     // days the app was opened
    var prayed: Set<String> = []     // days a full practice was finished
    var notes: [String: String] = [:]
    var checks: [String: [Bool]] = [:]
}
enum F { static let day: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f }() }

final class Store: ObservableObject {
    @Published var d: Model { didSet { if let x = try? JSONEncoder().encode(d) { UserDefaults.standard.set(x, forKey: "model") } } }
    var today: String { F.day.string(from: Date()) }
    init() {
        let m = (UserDefaults.standard.data(forKey: "model")).flatMap { try? JSONDecoder().decode(Model.self, from: $0) } ?? Model()
        d = m
        d.opened.insert(F.day.string(from: Date()))   // just opening the app counts
    }
    func markPrayed() { d.prayed.insert(today) }
    func key(_ date: Date, _ c: Calendar.Component) -> String {
        let cal = Calendar.current
        switch c {
        case .day: return F.day.string(from: date)
        case .weekOfYear: let x = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date); return "\(x.yearForWeekOfYear!)-W\(x.weekOfYear!)"
        case .month: let x = cal.dateComponents([.year, .month], from: date); return "\(x.year!)-\(x.month!)"
        default: return "\(cal.component(.year, from: date))"
        }
    }
    func streak(_ c: Calendar.Component) -> Int {
        let keys = Set(d.opened.compactMap { F.day.date(from: $0) }.map { key($0, c) })
        var n = 0, cur = Date()
        while keys.contains(key(cur, c)) { n += 1; cur = Calendar.current.date(byAdding: c, value: -1, to: cur)! }
        return n
    }
    func count(_ s: Set<String>, _ c: Calendar.Component) -> Int {
        s.compactMap { F.day.date(from: $0) }.filter { Calendar.current.isDate($0, equalTo: Date(), toGranularity: c) }.count
    }
}

// MARK: Salat al-Tasbih steps (the part you forget!)
struct Step: Identifiable {
    let id = UUID()
    let rakat: Int; let phase: String; let title: String; let say: String
    var arabic = ""; var count = 0; var pose = "figure.stand"
}
let TASBIH_AR = "سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَلَا إِلَٰهَ إِلَّا اللَّهُ وَاللَّهُ أَكْبَرُ"
let TASBIH_EN = "Subhanallahi wal-hamdulillahi wa la ilaha illallahu wallahu akbar"

func buildSteps() -> [Step] {
    var s: [Step] = []
    for r in 1...4 {
        if r == 1 { s.append(Step(rakat: r, phase: "Start", title: "Niyyah, Takbir, Thana", say: "Say Allahu Akbar, then Thana: Subhanakallahumma wa bihamdika wa tabarakasmuka wa ta'ala jadduka wa la ilaha ghayruk.")) }
        s.append(Step(rakat: r, phase: "Qiyam (standing)", title: "Tasbih ×15 — BEFORE Fatiha", say: TASBIH_EN, arabic: TASBIH_AR, count: 15))
        s.append(Step(rakat: r, phase: "Qiyam (standing)", title: "Audhu, Bismillah, Fatiha + a Surah", say: "Recite Al-Fatiha and a surah. No counting here."))
        s.append(Step(rakat: r, phase: "Qiyam (standing)", title: "Tasbih ×10 — before Ruku", say: TASBIH_EN, arabic: TASBIH_AR, count: 10))
        s.append(Step(rakat: r, phase: "RUKU ✓ (1 of 1)", title: "Ruku: Tasbih ×10", say: "Allahu Akbar → bow. Say Subhana Rabbiyal Azeem ×3, then:\n" + TASBIH_EN, arabic: TASBIH_AR, count: 10, pose: "chevron.down.circle"))
        s.append(Step(rakat: r, phase: "Qauma (rising)", title: "Stand up: Tasbih ×10", say: "Sami'Allahu liman hamidah, Rabbana lakal hamd. Stand straight, then:\n" + TASBIH_EN, arabic: TASBIH_AR, count: 10))
        s.append(Step(rakat: r, phase: "SAJDA 1 of 2", title: "Sajda 1: Tasbih ×10", say: "Allahu Akbar → sajda. Subhana Rabbiyal A'la ×3, then:\n" + TASBIH_EN, arabic: TASBIH_AR, count: 10, pose: "arrow.down.to.line"))
        s.append(Step(rakat: r, phase: "Jalsa (sit between sajdas)", title: "Sit: Tasbih ×10", say: "Allahu Akbar → sit up. Say Rabbighfir li, then:\n" + TASBIH_EN, arabic: TASBIH_AR, count: 10, pose: "circle.dashed"))
        s.append(Step(rakat: r, phase: "SAJDA 2 of 2", title: "Sajda 2: Tasbih ×10", say: "Allahu Akbar → second sajda. Subhana Rabbiyal A'la ×3, then:\n" + TASBIH_EN, arabic: TASBIH_AR, count: 10, pose: "arrow.down.to.line"))
        if r == 2 { s.append(Step(rakat: r, phase: "Sitting", title: "Tashahhud (At-Tahiyyat) only", say: "Sit, recite At-Tahiyyat, then stand for rakat 3. No tasbih counting here.", pose: "circle.dashed")) }
        if r == 4 { s.append(Step(rakat: r, phase: "Final sitting", title: "Tashahhud, Durood, Dua, Salam", say: "Recite At-Tahiyyat, Durood Ibrahim, a dua, then Salam right and left.", pose: "circle.dashed")) }
    }
    return s   // 75 tasbih per rakat = 300 total
}

final class Speaker: ObservableObject {
    let syn = AVSpeechSynthesizer()
    func say(_ t: String, _ lang: String = "en-US") {
        syn.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: t); u.voice = AVSpeechSynthesisVoice(language: lang); u.rate = 0.4
        syn.speak(u)
    }
}
