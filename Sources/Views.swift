import SwiftUI

struct RootView: View {
    @AppStorage("appearance") var appearance = 0
    var body: some View {
        TabView {
            PracticeTab().tabItem { Label("Practice", systemImage: "figure.stand") }
            ProgressTab().tabItem { Label("Progress", systemImage: "flame.fill") }
            LearnTab().tabItem { Label("Learn", systemImage: "book.fill") }
            DiaryTab().tabItem { Label("Diary", systemImage: "square.and.pencil") }
        }
        .padding()
        .toolbar { Picker("Theme", selection: $appearance) { Text("Auto").tag(0); Text("Light").tag(1); Text("Dark").tag(2) }.pickerStyle(.segmented) }
    }
}

struct PracticeTab: View {
    @EnvironmentObject var store: Store
    @StateObject var speaker = Speaker()
    @State var i = 0, tally = 0, elapsed = 0
    @State var voice = false
    let steps = buildSteps()
    let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 14) {
            if i >= steps.count { finished } else { stepView(steps[i]) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(tick) { _ in if i < steps.count { elapsed += 1 } }
    }

    var finished: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 90)).foregroundStyle(.green)
                .transition(.scale)
            Text("Salat al-Tasbih complete 🤲").font(.largeTitle.bold())
            Text("300 tasbih • \(elapsed / 60) min \(elapsed % 60) s").foregroundStyle(.secondary)
            Button("Practice again") { withAnimation { i = 0; tally = 0; elapsed = 0 } }.buttonStyle(.borderedProminent)
        }
    }

    func stepView(_ s: Step) -> some View {
        VStack(spacing: 14) {
            HStack {
                ForEach(1...4, id: \.self) { r in
                    Circle().fill(r <= s.rakat ? Color.green : Color.gray.opacity(0.3)).frame(width: 14, height: 14)
                }
                Text("Rakat \(s.rakat) of 4").font(.headline)
                Spacer()
                Toggle("Voice guide", isOn: $voice)
                Text(String(format: "%02d:%02d", elapsed / 60, elapsed % 60)).monospacedDigit().font(.title3)
            }
            Text(s.phase).font(.title.bold()).foregroundStyle(.orange)
                .id("p\(i)").transition(.scale.combined(with: .opacity))
            Image(systemName: s.pose).font(.system(size: 64)).foregroundStyle(.tint)
                .id("i\(i)").transition(.move(edge: .bottom).combined(with: .opacity))
            Text(s.title).font(.title2)
            if !s.arabic.isEmpty { Text(s.arabic).font(.system(size: 30)).multilineTextAlignment(.center) }
            Text(s.say).multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 560)
            if s.count > 0 {
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.25), lineWidth: 12)
                    Circle().trim(from: 0, to: CGFloat(tally) / CGFloat(s.count))
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90)).animation(.spring(), value: tally)
                    Text("\(tally)/\(s.count)").font(.system(size: 44, weight: .bold)).monospacedDigit()
                }.frame(width: 160, height: 160)
                Button("Tap to count  (Space)") { tap(s) }
                    .keyboardShortcut(.space, modifiers: []).buttonStyle(.borderedProminent).controlSize(.large)
            } else {
                Button("Done → Next  (Return)") { next() }
                    .keyboardShortcut(.return, modifiers: []).buttonStyle(.borderedProminent).controlSize(.large)
            }
            HStack {
                Button("◀︎ Back") { withAnimation { i = max(0, i - 1); tally = 0 } }
                Button("▶︎ Play recitation") { speaker.say(s.arabic.isEmpty ? s.say : s.arabic, s.arabic.isEmpty ? "en-US" : "ar-SA") }
                Button("Restart") { withAnimation { i = 0; tally = 0; elapsed = 0 } }
            }
        }
        .onAppear { if voice { announce(s) } }
    }

    func tap(_ s: Step) { tally += 1; if tally >= s.count { next() } }
    func next() {
        withAnimation(.spring()) { i += 1; tally = 0 }
        if i >= steps.count { store.markPrayed() } else if voice { announce(steps[i]) }
    }
    func announce(_ s: Step) { speaker.say("Rakat \(s.rakat). \(s.phase). \(s.title)") }
}

struct ProgressTab: View {
    @EnvironmentObject var store: Store
    @State var period = 0
    let periods: [(String, Calendar.Component)] = [("Daily", .day), ("Weekly", .weekOfYear), ("Monthly", .month), ("Yearly", .year)]
    var body: some View {
        let c = periods[period].1
        VStack(spacing: 20) {
            Picker("", selection: $period) { ForEach(0..<4) { Text(periods[$0].0).tag($0) } }.pickerStyle(.segmented)
            HStack(spacing: 16) {
                card("Days opened", "\(store.count(store.d.opened, c))", "book.fill")
                card("Salat al-Tasbih done", "\(store.count(store.d.prayed, c))", "checkmark.circle.fill")
                card("\(periods[period].0) streak 🔥", "\(store.streak(c))", "flame.fill")
            }
            Text("Streaks count any day you simply open the app.").foregroundStyle(.secondary)
            HStack(spacing: 16) {
                ForEach(0..<4) { card("\(periods[$0].0) streak", "\(store.streak(periods[$0].1))", "flame") }
            }
            Spacer()
        }.padding()
    }
    func card(_ t: String, _ v: String, _ icon: String) -> some View {
        VStack { Image(systemName: icon).font(.title); Text(v).font(.system(size: 40, weight: .bold)); Text(t).font(.caption) }
            .frame(maxWidth: .infinity).padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct LearnTab: View {
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 14) {
            Text("Salat al-Tasbih").font(.largeTitle.bold())
            sec("Quick map (4 rakat, 75 tasbih each = 300)", "Rakat 1: Thana → 15 → Fatiha+Surah → 10 → Ruku (10) → Qauma (10) → Sajda 1 (10) → Sit (10) → Sajda 2 (10).\nRakat 2: same, but NO Thana; after Sajda 2 sit for Tashahhud only. Rakat 3 & 4: same as 2; sit at the end for Tashahhud, Durood, Dua, Salam.\nEvery rakat: 1 Ruku, 2 Sajdas. 15 + 5×10 + 10 = 75.")
            sec("The tasbih", TASBIH_AR + "\n" + TASBIH_EN)
            sec("Dua (example)", "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ\nRabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina 'adhaban-nar.")
            sec("Benefit", "Reported to bring forgiveness of sins — early and late, old and new, intentional and unintentional, small and great.")
            sec("Hadith", "Abu Dawud 1297 / Ibn Majah 1387 (from Ibn Abbas): the Prophet ﷺ taught his uncle al-Abbas this prayer and said to pray it daily if able, otherwise weekly, monthly, yearly, or at least once in a lifetime. Scholars differ on its grading — please confirm details with a trusted scholar.")
            sec("Forgot your count?", "Don't restart. Carry on, and make up the missed tasbih in the next position (except sitting for Tashahhud/before Ruku rules differ by school — ask your scholar). Use the Practice tab to track rakat, ruku and sajda.")
        }.padding() }
    }
    func sec(_ t: String, _ b: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(t).font(.headline); Text(b).font(.body) }
            .padding().frame(maxWidth: .infinity, alignment: .leading).background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct DiaryTab: View {
    @EnvironmentObject var store: Store
    let items = ["Prayed Salat al-Tasbih", "Recited the dua", "Counted without losing track"]
    var body: some View {
        let k = store.today
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading) {
                Text("Today — \(k)").font(.title2.bold())
                ForEach(0..<items.count, id: \.self) { n in
                    Toggle(items[n], isOn: Binding(
                        get: { (store.d.checks[k] ?? [false, false, false])[n] },
                        set: { var a = store.d.checks[k] ?? [false, false, false]; a[n] = $0; store.d.checks[k] = a }))
                }
                Text("Diary note").font(.headline).padding(.top)
                TextEditor(text: Binding(get: { store.d.notes[k] ?? "" }, set: { store.d.notes[k] = $0 }))
                    .frame(minHeight: 200).border(Color.gray.opacity(0.4))
            }
            VStack(alignment: .leading) {
                Text("Past notes").font(.headline)
                List(store.d.notes.filter { !$0.value.isEmpty && $0.key != k }.sorted { $0.key > $1.key }, id: \.key) { e in
                    VStack(alignment: .leading) { Text(e.key).bold(); Text(e.value).lineLimit(3) }
                }
            }.frame(width: 260)
        }.padding()
    }
}
