import Foundation

/// Helper service to set up Supabase storage buckets programmatically
class SupabaseBucketSetup {
    private let supabaseUrl = SupabaseConfig.url
    private let supabaseKey = SupabaseConfig.anonKey
    private let urlSession = PerformanceOptimizer.shared.urlSession
    
    /// Creates the user-recordings bucket if it doesn't exist
    /// Note: This requires service role key for Management API access
    /// For anon key, use the SQL method instead
    func createUserRecordingsBucket(serviceRoleKey: String? = nil) async throws {
        // Use service role key if provided, otherwise use anon key (may not work)
        let key = serviceRoleKey ?? supabaseKey
        
        let url = URL(string: "\(SupabaseConfig.storageURL)/bucket")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "id": "user-recordings",
            "name": "user-recordings",
            "public": false,
            "file_size_limit": 52428800, // 50 MB
            "allowed_mime_types": ["audio/m4a", "audio/mpeg", "audio/x-m4a"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        // 200 = created, 409 = already exists (that's okay)
        guard (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 409 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Failed to create bucket: \(httpResponse.statusCode) - \(errorMessage)")
            throw SupabaseError.networkError(errorMessage)
        }
        
        if httpResponse.statusCode == 409 {
            print("ℹ️ Bucket 'user-recordings' already exists")
        } else {
            print("✅ Successfully created 'user-recordings' bucket")
        }
    }
    
    /// Alternative: Create bucket using SQL (run this in Supabase SQL Editor)
    static func getBucketCreationSQL() -> String {
        return """
        -- Create user-recordings storage bucket
        INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
        VALUES (
            'user-recordings',
            'user-recordings',
            false,
            52428800, -- 50 MB
            ARRAY['audio/m4a', 'audio/mpeg', 'audio/x-m4a']
        )
        ON CONFLICT (id) DO NOTHING;
        
        -- Verify bucket was created
        SELECT * FROM storage.buckets WHERE id = 'user-recordings';
        """
    }
}

