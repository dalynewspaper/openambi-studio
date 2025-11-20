import SwiftUI

struct RecordView: View {
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()
                
                waveformVisualizer
                
                timeDisplay
                
                recordButton
                
                controlButtons
                
                Spacer()
            }
            .padding()
            .background(AppTheme.background)
            .navigationTitle("Record")
        }
    }
    
    private var waveformVisualizer: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<30) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(isRecording ? AppTheme.gradient : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 6, height: CGFloat.random(in: 20...100))
                    .animation(.easeInOut(duration: 0.3).repeatForever(), value: isRecording)
            }
        }
        .frame(height: 120)
    }
    
    private var timeDisplay: some View {
        Text(timeString)
            .font(.system(size: 48, weight: .light, design: .monospaced))
            .foregroundStyle(.primary)
    }
    
    private var recordButton: some View {
        Button {
            isRecording.toggle()
        } label: {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : AppTheme.accent)
                    .frame(width: 100, height: 100)
                
                if isRecording {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white)
                        .frame(width: 32, height: 32)
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 32, height: 32)
                }
            }
            .shadow(color: isRecording ? .red.opacity(0.3) : AppTheme.accent.opacity(0.3), radius: 20)
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 40) {
            ControlButton(icon: "arrow.uturn.backward", color: .gray)
            ControlButton(icon: "pause.fill", color: .orange)
            ControlButton(icon: "checkmark", color: .green)
        }
    }
    
    private var timeString: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct ControlButton: View {
    let icon: String
    let color: Color
    
    var body: some View {
        Button {
            // Action
        } label: {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }
        }
    }
}

#Preview {
    RecordView()
}
