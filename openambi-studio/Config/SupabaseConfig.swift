import Foundation

struct SupabaseConfig {
    // Supabase project URL
    static let url = "https://zrczvgwexppvgxjxzdjw.supabase.co"
    
    // TODO: Replace with your actual Supabase anon key
    // Get this from your Supabase project: Settings > API > anon/public key
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpyY3p2Z3dleHBwdmd4anh6ZGp3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc4NTg2MTUsImV4cCI6MjA3MzQzNDYxNX0.EsgXvIZrHtmMqtfL5TlVscnhfhIRkBOFgYBjQZPLsac"
    
    // Base URL for REST API
    static var apiURL: String {
        "\(url)/rest/v1"
    }
    
    // Storage URL
    static var storageURL: String {
        "\(url)/storage/v1"
    }
}


