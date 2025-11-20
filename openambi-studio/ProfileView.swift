import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    profileHeader
                    statsSection
                    settingsList
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Profile")
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.gradient)
                    .frame(width: 100, height: 100)
                
                Text("JD")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            
            Text("John Doe")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Producer & Sound Engineer")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            ProfileStat(value: "47", label: "Tracks")
            Divider().frame(height: 40)
            ProfileStat(value: "8", label: "Projects")
            Divider().frame(height: 40)
            ProfileStat(value: "5", label: "Collabs")
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var settingsList: some View {
        VStack(spacing: 12) {
            SettingsRow(icon: "person.circle", title: "Edit Profile", color: .blue)
            SettingsRow(icon: "bell.fill", title: "Notifications", color: .orange)
            SettingsRow(icon: "cloud.fill", title: "Storage & Backup", color: .green)
            SettingsRow(icon: "lock.fill", title: "Privacy", color: .purple)
            SettingsRow(icon: "gearshape.fill", title: "Settings", color: .gray)
            SettingsRow(icon: "questionmark.circle", title: "Help & Support", color: .teal)
            SettingsRow(icon: "arrow.right.square", title: "Log Out", color: .red)
        }
    }
}

struct ProfileStat: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
            
            Text(title)
                .font(.subheadline)
            
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

#Preview {
    ProfileView()
}
