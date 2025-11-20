import SwiftUI

struct ProjectsView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(projects) { project in
                        ProjectCard(project: project)
                    }
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Projects")
            .searchable(text: $searchText)
            .toolbar {
                Button {
                    // Add new project
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    private let projects = [
        ProjectDetail(name: "Summer Vibes EP", tracks: 5, duration: "18:32", size: "245 MB"),
        ProjectDetail(name: "Midnight Sessions", tracks: 8, duration: "32:15", size: "412 MB"),
        ProjectDetail(name: "Acoustic Cover", tracks: 3, duration: "12:08", size: "156 MB"),
        ProjectDetail(name: "Beat Collection", tracks: 12, duration: "45:20", size: "687 MB")
    ]
}

struct ProjectCard: View {
    let project: ProjectDetail
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.gradient)
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "music.note.list")
                            .foregroundStyle(.white)
                            .font(.title2)
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                    
                    Text("\(project.tracks) tracks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Menu {
                    Button("Edit", systemImage: "pencil") { }
                    Button("Share", systemImage: "square.and.arrow.up") { }
                    Button("Delete", systemImage: "trash", role: .destructive) { }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            HStack {
                Label(project.duration, systemImage: "clock")
                Spacer()
                Label(project.size, systemImage: "internaldrive")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ProjectDetail: Identifiable {
    let id = UUID()
    let name: String
    let tracks: Int
    let duration: String
    let size: String
}

#Preview {
    ProjectsView()
}
