import WidgetKit
import SwiftUI

// MARK: - Widget Entry
struct OpenAmbiEntry: TimelineEntry {
    let date: Date
    let isPlaying: Bool
    let activeTrackCount: Int
    let masterVolume: Double
}

// MARK: - Widget Provider
struct OpenAmbiProvider: TimelineProvider {
    func placeholder(in context: Context) -> OpenAmbiEntry {
        OpenAmbiEntry(date: Date(), isPlaying: true, activeTrackCount: 3, masterVolume: 0.75)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (OpenAmbiEntry) -> Void) {
        let entry = OpenAmbiEntry(
            date: Date(),
            isPlaying: UserDefaults.standard.bool(forKey: "widget_isPlaying"),
            activeTrackCount: UserDefaults.standard.integer(forKey: "widget_activeTrackCount"),
            masterVolume: UserDefaults.standard.double(forKey: "widget_masterVolume")
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<OpenAmbiEntry>) -> Void) {
        let currentDate = Date()
        let entry = OpenAmbiEntry(
            date: currentDate,
            isPlaying: UserDefaults.standard.bool(forKey: "widget_isPlaying"),
            activeTrackCount: UserDefaults.standard.integer(forKey: "widget_activeTrackCount"),
            masterVolume: UserDefaults.standard.double(forKey: "widget_masterVolume")
        )
        
        // Update every minute
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View
struct OpenAmbiWidgetView: View {
    var entry: OpenAmbiProvider.Entry
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.01, blue: 0.11),
                    Color(red: 0.04, green: 0.38, blue: 0.51)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack(spacing: 8) {
                // Status indicator
                HStack {
                    Circle()
                        .fill(entry.isPlaying ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Text(entry.isPlaying ? "Playing" : "Paused")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                }
                
                // Active tracks count
                HStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("\(entry.activeTrackCount) active")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                }
                
                // Master volume
                HStack {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("\(Int(entry.masterVolume * 100))%")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                }
            }
            .padding(12)
        }
    }
}

// MARK: - Widget Configuration
struct OpenAmbiWidget: Widget {
    let kind: String = "OpenAmbiWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OpenAmbiProvider()) { entry in
            OpenAmbiWidgetView(entry: entry)
        }
        .configurationDisplayName("openambi")
        .description("Control your ambient soundscape from the Home Screen")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle
@main
struct OpenAmbiWidgetBundle: WidgetBundle {
    var body: some Widget {
        OpenAmbiWidget()
    }
}

