import SwiftUI
import Charts

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroSection
                    statsGrid
                    activityChart
                    recentProjects
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Dashboard")
        }
    }
    
    private var heroSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.gradient)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome Back")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text("3 active projects • 12 tracks recorded")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .frame(height: 140)
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(title: "Projects", value: "8", icon: "folder.fill", color: .blue)
            StatCard(title: "Tracks", value: "47", icon: "waveform", color: .green)
            StatCard(title: "Hours", value: "23.5", icon: "clock.fill", color: .orange)
            StatCard(title: "Collaborators", value: "5", icon: "person.2.fill", color: .purple)
        }
    }
    
    private var activityChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Activity")
                .font(.headline)
                .padding(.horizontal)
            
            Chart {
                ForEach(weeklyData) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Hours", item.hours)
                    )
                    .foregroundStyle(AppTheme.gradient)
                }
            }
            .frame(height: 200)
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private var recentProjects: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Projects")
                .font(.headline)
            
            ForEach(sampleProjects) { project in
                ProjectRow(project: project)
            }
        }
    }
    
    private let weeklyData = [
        ChartData(day: "Mon", hours: 3.5),
        ChartData(day: "Tue", hours: 2.8),
        ChartData(day: "Wed", hours: 4.2),
        ChartData(day: "Thu", hours: 3.1),
        ChartData(day: "Fri", hours: 5.5),
        ChartData(day: "Sat", hours: 2.0),
        ChartData(day: "Sun", hours: 1.5)
    ]
    
    private let sampleProjects = [
        Project(name: "Summer Vibes EP", tracks: 5, lastEdited: "2 hours ago"),
        Project(name: "Midnight Sessions", tracks: 8, lastEdited: "Yesterday"),
        Project(name: "Acoustic Cover", tracks: 3, lastEdited: "3 days ago")
    ]
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ProjectRow: View {
    let project: Project
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.gradient)
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(project.tracks) tracks • \(project.lastEdited)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ChartData: Identifiable {
    let id = UUID()
    let day: String
    let hours: Double
}

struct Project: Identifiable {
    let id = UUID()
    let name: String
    let tracks: Int
    let lastEdited: String
}

#Preview {
    DashboardView()
}
