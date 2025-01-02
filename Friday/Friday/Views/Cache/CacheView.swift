import SwiftUI

struct CacheView: View {
    @StateObject private var viewModel: CacheViewModel
    @State private var selectedTextFile: URL?
    @State private var showingTextContent = false
    
    init(path: URL? = nil) {
        _viewModel = StateObject(wrappedValue: CacheViewModel(path: path))
    }
    
    var body: some View {
        List {
            ForEach(viewModel.items) { item in
                if item.type == .folder {
                    NavigationLink(item.name) {
                        CacheView(path: item.url)
                    }
                    .listRowBackground(Color.clear)
                } else if item.type == .text {
                    CacheItemRow(item: item)
                        .onTapGesture {
                            print("Text file tapped: \(item.name)")
                            selectedTextFile = item.url
                            showingTextContent = true
                        }
                } else {
                    CacheItemRow(item: item)
                }
            }
        }
        .navigationTitle(viewModel.currentFolderName)
        .sheet(isPresented: $showingTextContent) {
            if let url = selectedTextFile {
                TextFileView(url: url)
            }
        }
    }
}

// MARK: - Supporting Views
struct TextFileView: View {
    let url: URL
    @State private var text: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(text)
                    .padding()
            }
            .navigationTitle(url.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadTextFile()
            print("Attempting to load file at: \(url.path)")
        }
    }
    
    private func loadTextFile() {
        do {
            text = try String(contentsOf: url, encoding: .utf8)
            print("Successfully loaded text: \(text)")
        } catch {
            text = "Error loading file: \(error.localizedDescription)"
            print("Error loading file: \(error)")
        }
    }
}

struct CacheItemRow: View {
    let item: CacheItem
    
    var body: some View {
        HStack {
            Image(systemName: item.iconName)
                .foregroundColor(item.iconColor)
            
            Text(item.name)
                .lineLimit(1)
            
            if let size = item.size {
                Spacer()
                Text(size)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - View Model
class CacheViewModel: ObservableObject {
    @Published private(set) var items: [CacheItem] = []
    private let currentPath: URL
    private let documentsPath: URL
    private let isRoot: Bool
    
    // Configuration for viewable folders
    private static let viewableFolders = [
        ViewableFolder(name: "Transcripts", icon: "doc.text.fill"),
        ViewableFolder(name: "Diaries", icon: "doc.text.fill")
    ]
    
    var currentFolderName: String {
        if isRoot {
            return "Cache"
        }
        // Find if current path matches any viewable folder
        if let folder = Self.viewableFolders.first(where: { currentPath.lastPathComponent == $0.name }) {
            return folder.name
        }
        return currentPath.lastPathComponent
    }
    
    init(path: URL? = nil) {
        documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        if let path = path {
            // For navigation to subfolders
            currentPath = path
            isRoot = false
        } else {
            // Start at root level
            currentPath = documentsPath
            isRoot = true
        }
        
        loadItems()
    }
    
    private func loadItems() {
        if isRoot {
            // At root level, show all viewable folders
            items = Self.viewableFolders.map { folder in
                let folderURL = documentsPath.appendingPathComponent(folder.name)
                return CacheItem(
                    url: folderURL,
                    name: folder.name,
                    type: .folder,
                    size: nil
                )
            }
            return
        }
        
        // Normal directory listing for subfolders
        let fileManager = FileManager.default
        
        guard isPathAllowed(currentPath) else {
            items = []
            return
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: currentPath, includingPropertiesForKeys: nil)
            items = contents.map { url in
                let type: CacheItemType = ((try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false) != nil)
                    ? .folder
                    : .getFileType(for: url)
                
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
                    .map { formatFileSize($0) }
                
                return CacheItem(
                    url: url,
                    name: url.lastPathComponent,
                    type: type,
                    size: size
                )
            }
            .sorted { $0.type.sortPriority < $1.type.sortPriority }
        } catch {
            print("Error reading directory: \(error)")
            items = []
        }
    }
    
    private func isPathAllowed(_ path: URL) -> Bool {
        // Check if the path is within any of the viewable folders
        return Self.viewableFolders.contains { folder in
            let folderPath = documentsPath.appendingPathComponent(folder.name)
            return path.path.hasPrefix(folderPath.path)
        }
    }
    
    private func formatFileSize(_ size: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

// MARK: - Models
struct ViewableFolder {
    let name: String
    let icon: String
    var allowedExtensions: [String] = ["txt"] // Default to text files only
}

struct CacheItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let type: CacheItemType
    let size: String?
    
    var iconName: String {
        switch type {
        case .folder: return "folder.fill"
        case .audio: return "music.note"
        case .text: return "doc.text.fill"
        case .unknown: return "doc.fill"
        }
    }
    
    var iconColor: Color {
        switch type {
        case .folder: return .blue
        case .audio: return .purple
        case .text: return .green
        case .unknown: return .gray
        }
    }
}

enum CacheItemType {
    case folder, audio, text, unknown
    
    var sortPriority: Int {
        switch self {
        case .folder: return 0
        case .audio: return 1
        case .text: return 2
        case .unknown: return 3
        }
    }
    
    static func getFileType(for url: URL) -> CacheItemType {
        switch url.pathExtension.lowercased() {
        case "m4a": return .audio
        case "txt": return .text
        default: return .unknown
        }
    }
}
