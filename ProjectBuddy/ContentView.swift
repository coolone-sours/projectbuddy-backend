import SwiftUI
import Combine

struct ContentView: View {
    // MARK: - Checklist
    @State private var tasks: [String] = ["Pick a topic", "Find 3 facts", "Make a poster", "Practice talking"]
    @State private var done: Set<Int> = []
    @State private var newTask: String = ""

    // MARK: - Notes
    @State private var notes: String = "Type your project ideas here..."

    // MARK: - Timer settings (Dev Panel can change these)
    @State private var focusMinutes: Int = 10
    @State private var breakMinutes: Int = 2

    // MARK: - Timer runtime
    @State private var secondsLeft: Int = 10 * 60
    @State private var isRunning: Bool = false
    @State private var isBreak: Bool = false

    // MARK: - Dev Panel
    @State private var showDevPanel: Bool = false
    @State private var hackerGlow: Bool = true
    @State private var onlineMode: Bool = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Backend URL (your local server)
    private let backendURL = URL(string: "http://127.0.0.1:8787/chat")!

    // MARK: - AI Chat
    struct ChatMessage: Identifiable, Equatable {
        let id = UUID()
        let role: String   // "user" or "assistant"
        let text: String
    }

    @State private var messages: [ChatMessage] = [
        .init(role: "assistant", text: "Ready. Toggle Online Mode in Dev Panel (⌘D) if your backend is running.")
    ]
    @State private var chatInput: String = ""
    @State private var isSending: Bool = false
    @State private var chatError: String? = nil

    // MARK: - Hacker colors
    let bg = Color(red: 0.05, green: 0.06, blue: 0.08)
    let panel = Color(red: 0.09, green: 0.11, blue: 0.15)
    let neon = Color(red: 0.25, green: 1.0, blue: 0.55)
    let neon2 = Color(red: 0.35, green: 0.75, blue: 1.0)

    // MARK: - Root
    var body: some View {
        TabView {
            buddyTab
                .tabItem { Label("Buddy", systemImage: "checklist") }

            chatTab
                .tabItem { Label("Chat", systemImage: "message") }
        }
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in
            guard isRunning else { return }
            secondsLeft -= 1
            if secondsLeft <= 0 { swapFocusBreak() }
        }
        // ⌘D opens Dev Panel
        .keyboardShortcutDevPanel { showDevPanel.toggle() }
        .sheet(isPresented: $showDevPanel) {
            DevPanelView(
                focusMinutes: $focusMinutes,
                breakMinutes: $breakMinutes,
                hackerGlow: $hackerGlow,
                onlineMode: $onlineMode,
                onApply: {
                    isRunning = false
                    secondsLeft = (isBreak ? breakMinutes : focusMinutes) * 60
                },
                onResetAll: resetAll
            )
            .preferredColorScheme(.dark)
        }
        .onAppear { secondsLeft = focusMinutes * 60 }
    }

    // MARK: - Buddy Tab
    var buddyTab: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                header

                GroupBox { timerView } label: { label("⏱️ FOCUS TIMER") }
                    .groupBoxStyle(HackerGroupBoxStyle(panel: panel, neon: neon, glow: hackerGlow))

                GroupBox { checklistView } label: { label("✅ CHECKLIST") }
                    .groupBoxStyle(HackerGroupBoxStyle(panel: panel, neon: neon2, glow: hackerGlow))

                GroupBox { notesView } label: { label("📝 NOTES") }
                    .groupBoxStyle(HackerGroupBoxStyle(panel: panel, neon: neon, glow: hackerGlow))

                Spacer()

                Text("Tip: Press ⌘D for Dev Panel")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(16)
            .frame(minWidth: 560, minHeight: 680)
        }
    }

    // MARK: - Chat Tab
    var chatTab: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text("CHAT // \(onlineMode ? "ONLINE" : "LOCAL")")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(neon)
                    .shadow(color: neon.opacity(hackerGlow ? 0.8 : 0.0), radius: hackerGlow ? 10 : 0)

                HStack {
                    Text(onlineMode ? "MODE: ONLINE (backend)" : "MODE: LOCAL (offline)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(onlineMode ? neon2 : .white.opacity(0.6))
                    Spacer()
                }

                if let chatError {
                    Text("ERR: \(chatError)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.red)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { msg in
                            HStack {
                                if msg.role == "assistant" {
                                    bubble(msg.text, neon: neon)
                                    Spacer(minLength: 30)
                                } else {
                                    Spacer(minLength: 30)
                                    bubble(msg.text, neon: neon2)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
                .background(panel.opacity(0.35))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(neon.opacity(0.22), lineWidth: 1)
                )

                HStack(spacing: 10) {
                    TextField("Ask for help…", text: $chatInput)
                        .textFieldStyle(HackerTextFieldStyle(panel: panel, neon: neon))

                    Button(isSending ? "..." : "SEND") {
                        Task { await sendChat() }
                    }
                    .disabled(isSending)
                    .buttonStyle(HackerButtonStyle(neon: neon, glow: hackerGlow))
                }

                Text(onlineMode ? "Backend: \(backendURL.absoluteString)" : "Local AI only (no internet)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(16)
            .frame(minWidth: 560, minHeight: 680)
        }
    }

    // MARK: - UI Pieces
    var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROJECT BUDDY")
                .font(.system(size: 30, weight: .black, design: .monospaced))
                .foregroundStyle(neon)
                .shadow(color: neon.opacity(hackerGlow ? 0.8 : 0.0), radius: hackerGlow ? 10 : 0)

            Text("Hacker Mode: ON")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.75))
    }

    var timerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(timeString(secondsLeft))
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundStyle(neon)
                    .shadow(color: neon.opacity(hackerGlow ? 0.85 : 0.0), radius: hackerGlow ? 10 : 0)

                Spacer()

                Button(isRunning ? "PAUSE" : "START") { isRunning.toggle() }
                    .buttonStyle(HackerButtonStyle(neon: neon, glow: hackerGlow))

                Button("RESET") {
                    isRunning = false
                    isBreak = false
                    secondsLeft = focusMinutes * 60
                }
                .buttonStyle(HackerButtonStyle(neon: neon2, glow: hackerGlow))
            }

            Text(isBreak ? "STATUS: BREAK MODE  // chill 😄" : "STATUS: FOCUS MODE  // go 💪")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))

            HStack {
                Text("SYS")
                Spacer()
                Text("CPU: \(isRunning ? "42%" : "3%")  RAM: 1.\(isRunning ? "7" : "2")GB")
            }
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .foregroundStyle(.white.opacity(0.55))
            .padding(.top, 2)
        }
    }

    var checklistView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(tasks.indices, id: \.self) { i in
                HStack {
                    Button {
                        if done.contains(i) { done.remove(i) } else { done.insert(i) }
                    } label: {
                        Image(systemName: done.contains(i) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(done.contains(i) ? neon : .white.opacity(0.55))
                    }
                    .buttonStyle(.plain)

                    Text(tasks[i])
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .strikethrough(done.contains(i))
                        .foregroundStyle(done.contains(i) ? .white.opacity(0.45) : .white.opacity(0.85))

                    Spacer()

                    Button(role: .destructive) {
                        tasks.remove(at: i)
                        done = Set(done.compactMap { $0 == i ? nil : ($0 > i ? $0 - 1 : $0) })
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
                Divider().overlay(.white.opacity(0.08))
            }

            HStack {
                TextField("Add new mission…", text: $newTask)
                    .textFieldStyle(HackerTextFieldStyle(panel: panel, neon: neon))

                Button("ADD") {
                    let t = newTask.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    tasks.append(t)
                    newTask = ""
                }
                .buttonStyle(HackerButtonStyle(neon: neon, glow: hackerGlow))
            }
            .padding(.top, 6)
        }
    }

    var notesView: some View {
        TextEditor(text: $notes)
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .foregroundStyle(.white.opacity(0.9))
            .scrollContentBackground(.hidden)
            .background(panel.opacity(0.7))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(neon.opacity(0.35), lineWidth: 1)
                    .shadow(color: neon.opacity(hackerGlow ? 0.5 : 0.0), radius: hackerGlow ? 8 : 0)
            )
            .frame(minHeight: 140)
    }

    // MARK: - Logic
    func swapFocusBreak() {
        if isBreak {
            isBreak = false
            secondsLeft = focusMinutes * 60
        } else {
            isBreak = true
            secondsLeft = breakMinutes * 60
        }
    }

    func resetAll() {
        isRunning = false
        isBreak = false
        secondsLeft = focusMinutes * 60
        tasks = ["Pick a topic", "Find 3 facts", "Make a poster", "Practice talking"]
        done = []
        notes = "Type your project ideas here..."
        newTask = ""
        messages = [.init(role: "assistant", text: "Ready. Toggle Online Mode in Dev Panel (⌘D) if your backend is running.")]
        chatInput = ""
        isSending = false
        chatError = nil
    }

    func timeString(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%02d:%02d", s/60, s%60)
    }

    // MARK: - Chat send (Online OR Local fallback)
    @MainActor
    func sendChat() async {
        let text = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        chatError = nil
        chatInput = ""
        messages.append(.init(role: "user", text: text))
        isSending = true

        do {
            if onlineMode {
                let reply = try await callBackend(prompt: text)
                messages.append(.init(role: "assistant", text: reply.isEmpty ? "(No reply)" : reply))
            } else {
                try? await Task.sleep(nanoseconds: 350_000_000)
                let reply = generateLocalReply(for: text)
                messages.append(.init(role: "assistant", text: reply))
            }
        } catch {
            chatError = error.localizedDescription
            let local = generateLocalReply(for: text)
            messages.append(.init(role: "assistant", text: "(Online failed, using local)\n\n" + local))
        }

        isSending = false
    }

    // MARK: - Backend call
    struct BackendResponse: Decodable { let text: String }

    func callBackend(prompt: String) async throws -> String {
        var req = URLRequest(url: backendURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "prompt": prompt,
            "history": messages.map { ["role": $0.role, "text": $0.text] }
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "Backend", code: code, userInfo: [NSLocalizedDescriptionKey: "Backend HTTP \(code)"])
        }

        if let decoded = try? JSONDecoder().decode(BackendResponse.self, from: data) {
            return decoded.text
        }

        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let t = obj["text"] as? String { return t }
            if let t = obj["reply"] as? String { return t }
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Local AI fallback
    func generateLocalReply(for input: String) -> String {
        let lower = input.lowercased()

        if lower.contains("idea") || lower.contains("topic") {
            return "Project ideas:\n• Volcano\n• Space / planets\n• Sharks\n• Robots\n• Magnets\n• Electricity\n\nTell me what you like and I’ll help you plan it."
        }

        if lower.contains("plan") || lower.contains("steps") {
            return "Project Plan:\n1) Pick topic\n2) Find 3–5 facts\n3) Write an outline\n4) Make poster/slides\n5) Practice 2 times\n6) Present 😎"
        }

        if lower.contains("checklist") {
            return "Checklist:\n☐ Title\n☐ 3 facts\n☐ 2 pictures\n☐ Conclusion\n☐ Practice speech\n\nWant me to turn your topic into a custom checklist?"
        }

        if lower.contains("write") || lower.contains("paragraph") {
            return "Paragraph starter:\n\"My project is about ____. It is important because ____. One interesting fact is ____. Another cool fact is ____.\""
        }

        if lower.contains("practice") || lower.contains("questions") {
            return "Practice mode: I’ll ask you 3 questions.\n1) What is your topic?\n2) What’s your coolest fact?\n3) Why should people care?\n\nAnswer #1 first!"
        }

        return "Tell me your topic (like ‘volcano’ or ‘space’) and what you need: plan / checklist / writing / practice."
    }

    // MARK: - Chat bubble
    @ViewBuilder
    func bubble(_ text: String, neon: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(panel.opacity(0.85))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(neon.opacity(0.35), lineWidth: 1)
                    .shadow(color: neon.opacity(hackerGlow ? 0.45 : 0.0), radius: hackerGlow ? 10 : 0)
            )
    }
}

// MARK: - Dev Panel
struct DevPanelView: View {
    @Binding var focusMinutes: Int
    @Binding var breakMinutes: Int
    @Binding var hackerGlow: Bool
    @Binding var onlineMode: Bool

    var onApply: () -> Void
    var onResetAll: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text("🛠 DEV PANEL")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.green)

                Text("⌘D opens this panel")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))

                Divider().overlay(.white.opacity(0.15))

                Stepper("Focus Minutes: \(focusMinutes)", value: $focusMinutes, in: 1...60)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))

                Stepper("Break Minutes: \(breakMinutes)", value: $breakMinutes, in: 1...30)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))

                Toggle("Hacker Glow", isOn: $hackerGlow)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .toggleStyle(.switch)
                    .foregroundStyle(.white.opacity(0.9))

                Toggle("Online Mode (uses backend)", isOn: $onlineMode)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .toggleStyle(.switch)
                    .foregroundStyle(.white.opacity(0.9))

                HStack(spacing: 10) {
                    Button("APPLY") { onApply() }
                        .buttonStyle(HackerButtonStyle(neon: .green, glow: true))

                    Button("RESET ALL") { onResetAll() }
                        .buttonStyle(HackerButtonStyle(neon: .red, glow: false))

                    Spacer()

                    Button("CLOSE") { dismiss() }
                        .buttonStyle(HackerButtonStyle(neon: .white.opacity(0.7), glow: false))
                }

                Spacer()
            }
            .padding(18)
            .frame(minWidth: 520, minHeight: 320)
            .background(Color(red: 0.10, green: 0.11, blue: 0.14))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.green.opacity(0.35), lineWidth: 1)
            )
        }
    }
}

// MARK: - Styles
struct HackerGroupBoxStyle: GroupBoxStyle {
    var panel: Color
    var neon: Color
    var glow: Bool

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            configuration.label
            configuration.content
        }
        .padding(14)
        .background(panel.opacity(0.85))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(neon.opacity(0.35), lineWidth: 1)
                .shadow(color: neon.opacity(glow ? 0.55 : 0.0), radius: glow ? 12 : 0)
        )
    }
}

struct HackerButtonStyle: ButtonStyle {
    var neon: Color
    var glow: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(.black)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(neon.opacity(configuration.isPressed ? 0.65 : 0.9))
            .cornerRadius(10)
            .shadow(color: neon.opacity(glow ? 0.6 : 0.0), radius: glow ? 10 : 0)
    }
}

struct HackerTextFieldStyle: TextFieldStyle {
    var panel: Color
    var neon: Color

    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.9))
            .padding(10)
            .background(panel.opacity(0.85))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(neon.opacity(0.30), lineWidth: 1)
            )
    }
}

// MARK: - Keyboard shortcut helper (⌘D)
struct DevPanelShortcutModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .background(
                Button("") { action() }
                    .keyboardShortcut("d", modifiers: [.command])
                    .opacity(0.0)
            )
    }
}

extension View {
    func keyboardShortcutDevPanel(_ action: @escaping () -> Void) -> some View {
        self.modifier(DevPanelShortcutModifier(action: action))
    }
}
