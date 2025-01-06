import SwiftUI
import UIKit

struct DefaultPrompts {
    static let guidelines = [
        "The diary should be no longer than 200 words but no shorter than 50 words.",
        "Use clear, concise, and natural language.",
        "You may receive content in multiple languages; translate and summarise all content into English.",
        "Use a first-person tone, suitable for a personal diary.",
        "Focus on describing activities and events as they are mentioned in the transcript.",
        "Do not infer or summarise emotions, moods, or feelings beyond what is explicitly stated.",
        "Exclude greetings or signatures.",
        "Structure the diary entry as a single coherent paragraph.",
        "Avoid including repetitive or unrecognisable sounds that do not add meaningful context."
    ]
    
    static func createDefaultNotes() -> [Note] {
        guidelines.map { Note(content: $0) }
    }
}

struct ProfileView: View {
    @State private var userNotes: [Note] = []
    @State private var showingNewNote = false
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("System prompts")) {
                    ForEach(userNotes) { note in
                        NavigationLink(destination: NoteEditView(note: binding(for: note), onSave: saveNotes)) {
                            NoteRowView(note: note)
                        }
                    }
                    .onDelete(perform: deleteNotes)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewNote = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingResetAlert = true }) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
            .alert("Reset to Defaults", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetToDefaults()
                }
            } message: {
                Text("This will reset all prompts to their default values. This action cannot be undone.")
            }
            .sheet(isPresented: $showingNewNote) {
                NavigationView {
                    NoteEditView(note: $userNotes.new, onSave: saveNotes)
                }
            }
        }
        .onAppear(perform: loadNotes)
    }
    
    private func loadNotes() {
        if let data = UserDefaults.standard.data(forKey: "SystemPromptNotes"),
           let savedNotes = try? JSONDecoder().decode([Note].self, from: data) {
            userNotes = savedNotes
        } else {
            // First launch: load default prompts
            userNotes = DefaultPrompts.createDefaultNotes()
            saveNotes()
        }
    }
    
    func saveNotes() {
        if let encoded = try? JSONEncoder().encode(userNotes) {
            UserDefaults.standard.set(encoded, forKey: "SystemPromptNotes")
        }
    }
    
    private func binding(for note: Note) -> Binding<Note> {
        Binding(
            get: { note },
            set: { newValue in
                if let index = userNotes.firstIndex(where: { $0.id == note.id }) {
                    userNotes[index] = newValue
                }
            }
        )
    }
    
    private func deleteNotes(at offsets: IndexSet) {
        userNotes.remove(atOffsets: offsets)
        saveNotes()
    }
    
    private func resetToDefaults() {
        userNotes = DefaultPrompts.createDefaultNotes()
        saveNotes()
    }
}

struct Note: Identifiable, Codable {
    let id: UUID
    var content: String
    
    init(id: UUID = UUID(), content: String = "") {
        self.id = id
        self.content = content
    }
}

struct NoteRowView: View {
    let note: Note
    
    var body: some View {
        Text(note.content.prefix(50) + (note.content.count > 50 ? "..." : ""))
            .lineLimit(2)
            .font(.body)
    }
}

struct NoteEditView: View {
    @Binding var note: Note
    @Environment(\.dismiss) private var dismiss
    @State private var tempNote: Note
    @FocusState private var isFocused: Bool
    
    var onSave: (() -> Void)?
    
    init(note: Binding<Note>, onSave: (() -> Void)? = nil) {
        self._note = note
        self._tempNote = State(initialValue: note.wrappedValue)
        self.onSave = onSave
    }
    
    var body: some View {
        Form {
            TextEditor(text: $tempNote.content)
                .focused($isFocused)
                .frame(minHeight: 300)
        }
        .navigationTitle("Prompt Guideline")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    note = tempNote
                    onSave?()
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            isFocused = tempNote.content.isEmpty
        }
        .interactiveDismissDisabled()
    }
}

extension Array where Element == Note {
    var new: Note {
        get { Note() }
        set {
            guard !newValue.content.isEmpty else { return }
            self.append(newValue)
        }
    }
}
