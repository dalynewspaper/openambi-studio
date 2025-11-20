import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    searchBar
                    filterChips
                    tracksList
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Library")
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search tracks, samples...", text: .constant(""))
                .textFieldStyle(.plain)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(title: "All", isSelected: true)
                FilterChip(title: "Vocals", isSelected: false)
                FilterChip(title: "Drums", isSelected: false)
                FilterChip(title: "Bass", isSelected: false)
                FilterChip(title: "Synths", isSelected: false)
            }
        }
    }
    
    private var tracksList: some View {
        VStack(spacing: 12) {
            ForEach(sampleTracks) { track in
                TrackRow(track: track)
            }
        }
    }
    
    private let sampleTracks = [
        Track(name: "Vocal Take 1", duration: "3:24", waveformColor: .blue),
        Track(name: "Drum Loop 808", duration: "2:10", waveformColor: .green),
        Track(name: "Bass Line V2", duration: "4:05", waveformColor: .orange),
        Track(name: "Synth Pad", duration: "5:30", waveformColor: .purple),
        Track(name: "Guitar Riff", duration: "1:45", waveformColor: .pink)
    ]
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.accent : AppTheme.cardBackground)
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
    }
}

struct TrackRow: View {
    let track: Track
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(track.waveformColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "waveform")
                    .foregroundStyle(track.waveformColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(track.duration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct Track: Identifiable {
    let id = UUID()
    let name: String
    let duration: String
    let waveformColor: Color
}

#Preview {
    LibraryView()
}
