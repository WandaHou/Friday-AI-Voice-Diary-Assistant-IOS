import SwiftUI

// MARK: - Models
enum CacheItemType {
    case folder, json, text, unknown
    
    var sortPriority: Int {
        switch self {
        case .folder: return 0
        case .json: return 1
        case .text: return 2
        case .unknown: return 3
        }
    }
    
    static func getFileType(for url: URL) -> CacheItemType {
        switch url.pathExtension.lowercased() {
        case "json": return .json
        case "txt": return .text
        default: return .unknown
        }
    }
}

struct CacheItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let type: CacheItemType
    let size: String?
    let date: Date?
    
    var iconName: String {
        switch type {
        case .folder: return "folder.fill"
        case .json: return "doc.text.fill"
        case .text: return "doc.text"
        case .unknown: return "doc.fill"
        }
    }
    
    var iconColor: Color {
        switch type {
        case .folder: return .blue
        case .json: return .green
        case .text: return .yellow
        case .unknown: return .gray
        }
    }
}

struct CacheEntry: Codable {
    let timestamp: Date
    let content: String
    var metadata: [String: String]
}

struct ViewableFolder {
    let name: String
    let icon: String
    var allowedExtensions: [String] = ["json"]
}

// MARK: - Views
struct CacheView: View {
    @StateObject private var viewModel: CacheViewModel
    @State private var selectedFile: URL?
    @State private var showingContent = false
    
    init(path: URL? = nil) {
        _viewModel = StateObject(wrappedValue: CacheViewModel(path: path))
        _selectedFile = State(initialValue: nil)
        _showingContent = State(initialValue: false)
    }
    
    var body: some View {
        List {
            ForEach(viewModel.items) { item in
                if item.type == .folder {
                    NavigationLink(item.name) {
                        CacheView(path: item.url)
                    }
                } else if item.type == .json || item.type == .text {
                    CacheItemRow(item: item) {
                        selectedFile = item.url
                        showingContent = true
                    }
                }
            }
        }
        .navigationTitle(viewModel.currentFolderName)
        .background(
            FileViewerSheet(
                isPresented: $showingContent,
                url: selectedFile,
                onDismiss: { selectedFile = nil }
            )
        )
    }
}

struct FileViewerSheet: View {
    @Binding var isPresented: Bool
    let url: URL?
    let onDismiss: () -> Void
    
    var body: some View {
        EmptyView()
            .sheet(isPresented: $isPresented, onDismiss: onDismiss) {
                if let url = url {
                    FileContentView(url: url)
                }
            }
    }
}

struct CacheItemRow: View {
    let item: CacheItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: item.iconName)
                    .foregroundColor(item.iconColor)
                
                Text(item.name)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                if let size = item.size {
                    Spacer()
                    Text(size)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        //.buttonStyle(PlainButtonStyle())
    }
}

struct FileContentView: View {
    let url: URL
    @Environment(\.dismiss) var dismiss
    @State private var content: String = "Loading..."
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding()
                }
            }
            .navigationTitle(url.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
        .onAppear {
            loadContent()
        }
    }
    
    private func loadContent() {
        do {
            let data = try Data(contentsOf: url)
            if url.pathExtension.lowercased() == "json" {
                let json = try JSONSerialization.jsonObject(with: data)
                let prettyData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
                content = String(data: prettyData, encoding: .utf8) ?? "Invalid JSON content"
            } else {
                content = String(data: data, encoding: .utf8) ?? "Invalid text content"
            }
        } catch {
            content = "Error loading file: \(error.localizedDescription)"
        }
    }
}

// MARK: - ViewModel
class CacheViewModel: ObservableObject {
    @Published private(set) var items: [CacheItem] = []
    private let currentPath: URL
    private let documentsPath: URL
    private let isRoot: Bool
    
    private static let viewableFolders = [
        ViewableFolder(name: "Transcripts", icon: "doc.text.fill"),
        ViewableFolder(name: "Diaries", icon: "doc.text.fill")
    ]
    
    var currentFolderName: String {
        if isRoot {
            return "Cache"
        }
        if let folder = Self.viewableFolders.first(where: { currentPath.lastPathComponent == $0.name }) {
            return folder.name
        }
        return currentPath.lastPathComponent
    }
    
    init(path: URL? = nil) {
        documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        if let path = path {
            currentPath = path
            isRoot = false
        } else {
            currentPath = documentsPath
            isRoot = true
        }
        
        loadItems()
    }
    
    private func loadItems() {
        if isRoot {
            items = Self.viewableFolders.map { folder in
                let folderURL = documentsPath.appendingPathComponent(folder.name)
                return CacheItem(
                    url: folderURL,
                    name: folder.name,
                    type: .folder,
                    size: nil,
                    date: nil
                )
            }
            return
        }
        
        let fileManager = FileManager.default
        
        guard isPathAllowed(currentPath) else {
            items = []
            return
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: currentPath,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey]
            )
            
            items = contents.map { url in
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let type: CacheItemType = isDirectory ? .folder : .getFileType(for: url)
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
                    .map { formatFileSize($0) }
                
                return CacheItem(
                    url: url,
                    name: url.lastPathComponent,
                    type: type,
                    size: size,
                    date: try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                )
            }
            .sorted { item1, item2 in
                // First sort by type
                if item1.type.sortPriority != item2.type.sortPriority {
                    return item1.type.sortPriority < item2.type.sortPriority
                }
                // Then sort by date (most recent first)
                return (item1.date ?? .distantPast) > (item2.date ?? .distantPast)
            }
        } catch {
            print("Error reading directory: \(error)")
            items = []
        }
    }
    
    private func isPathAllowed(_ path: URL) -> Bool {
        return Self.viewableFolders.contains { folder in
            let folderPath = documentsPath.appendingPathComponent(folder.name)
            return path.path.hasPrefix(folderPath.path)
        }
    }
    
    private func formatFileSize(_ size: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

//func createTestTextFile() {
//    guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
//        print("Could not find documents directory")
//        return
//    }
//
//    let content = "Hello world."
//    let diaryPath = documentsPath.appendingPathComponent("Diaries")
//    let testFile = diaryPath.appendingPathComponent("test.txt")
//
//    do {
//        try content.write(to: testFile, atomically: true, encoding: .utf8)
//        print("Created test text file at: \(testFile.path)")
//    } catch {
//        print("Error creating test file: \(error)")
//    }
//}
