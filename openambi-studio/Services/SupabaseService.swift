import Foundation

class SupabaseService: ObservableObject {
    private let supabaseUrl = SupabaseConfig.url
    private let supabaseKey = SupabaseConfig.anonKey
    
    // Use optimized URLSession with connection pooling
    private let urlSession = PerformanceOptimizer.shared.urlSession
    
    // MARK: - Helper: Create Authenticated Request
    private func createRequest(url: URL, method: String = "GET", accessToken: String? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Use access token if provided (authenticated request), otherwise use anon key
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    // MARK: - Fetch Audio Tracks
    func fetchAudioTracks() async throws -> [AudioTrack] {
        // Try ambient_sounds table first (matches your storage bucket name)
        let tableNames = ["ambient_sounds", "audio_tracks"]
        
        for tableName in tableNames {
            do {
                let url = URL(string: "\(SupabaseConfig.apiURL)/\(tableName)?select=*")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
                request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                    continue // Try next table
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                    print("ℹ️ Table '\(tableName)' not found or error: \(httpResponse.statusCode)")
                    continue // Try next table
            }
            
            let decoder = JSONDecoder()
            let supabaseTracks = try decoder.decode([SupabaseAmbientSound].self, from: data)
                
                print("✅ Successfully fetched \(supabaseTracks.count) tracks from '\(tableName)' table")
            
            // Filter out tracks that don't actually exist (user-specified exclusion list)
            let excludedTrackNames = [
                "Ticking Clock",
                "City Rain",
                "Distant Traffic",
                "Train Rumble",
                "Café Chatter",
                "Cafe Chatter" // Handle both spellings
            ]
            
            // Log which tracks are being filtered out
            let filteredOut = supabaseTracks.filter { excludedTrackNames.contains($0.name) }
            if !filteredOut.isEmpty {
                print("🚫 Filtering out \(filteredOut.count) tracks that don't exist: \(filteredOut.map { $0.name }.joined(separator: ", "))")
            }
            
            // Convert Supabase format to AudioTrack, filtering out excluded tracks
            return supabaseTracks
                .filter { !excludedTrackNames.contains($0.name) }
                .map { supabaseTrack in
                // Construct full audio URL from file_path
                    // file_path can be: "nature/rain.m4a", "indoor/fireplace.m4a", or full URL
                let audioUrl: String
                if supabaseTrack.file_path.hasPrefix("http") {
                    // Already a full URL
                    audioUrl = supabaseTrack.file_path
                } else {
                        // Construct storage URL - use ambient-sounds bucket
                        // Remove leading slash if present, keep folder structure
                        var cleanPath = supabaseTrack.file_path.hasPrefix("/") 
                            ? String(supabaseTrack.file_path.dropFirst()) 
                            : supabaseTrack.file_path
                        
                        // FIX: Convert .mp3/.mp4 extensions to .m4a if they exist
                        // The database might have old extensions, but files are actually .m4a
                        if cleanPath.hasSuffix(".mp3") {
                            cleanPath = String(cleanPath.dropLast(4)) + ".m4a"
                        } else if cleanPath.hasSuffix(".mp4") {
                            cleanPath = String(cleanPath.dropLast(4)) + ".m4a"
                        }
                        
                        // Also handle case sensitivity issues (Tibetan-Bowl vs tibetan-bowl)
                        if cleanPath.contains("Tibetan-Bowl") {
                            cleanPath = cleanPath.replacingOccurrences(of: "Tibetan-Bowl", with: "tibetan-bowl")
                        }
                        
                        // URL encode the path to handle special characters
                        let encodedPath = cleanPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanPath
                        audioUrl = "\(SupabaseConfig.storageURL)/object/public/ambient-sounds/\(encodedPath)"
                }
                
                    let track = AudioTrack(
                    id: UUID(uuidString: supabaseTrack.id) ?? UUID(),
                    name: supabaseTrack.name,
                    category: supabaseTrack.category,
                    icon: iconForTrack(name: supabaseTrack.name, category: supabaseTrack.category),
                    description: nil,
                    audioUrl: audioUrl,
                    isActive: false,
                    volume: 0.0
                )
                    
                    // Debug: Print constructed URL
                    print("🔗 Constructed URL for \(track.name): \(audioUrl)")
                    
                    return track
            }
        } catch {
                print("ℹ️ Error trying table '\(tableName)': \(error.localizedDescription)")
                continue // Try next table
            }
        }
        
        // If all tables failed, return empty array (only use tracks from Supabase)
        print("⚠️ No valid tables found in Supabase - returning empty array")
            return []
    }
    
    // MARK: - Fetch Presets
    func fetchPresets(accessToken: String? = nil) async throws -> [Preset] {
        // Check if presets table exists, otherwise use sample presets
        let url = URL(string: "\(SupabaseConfig.apiURL)/presets?select=*")!
        var request = createRequest(url: url, method: "GET", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Prefer")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Presets table doesn't exist, use sample presets
                print("ℹ️ Presets table not found, using sample presets")
                return samplePresets()
            }
            
            let decoder = JSONDecoder()
            let presets = try decoder.decode([SupabasePreset].self, from: data)
            
            // Convert Supabase format to Preset
            return presets.map { supabasePreset in
                Preset(
                    id: UUID(uuidString: supabasePreset.id) ?? UUID(),
                    name: supabasePreset.name,
                    icon: supabasePreset.icon,
                    description: supabasePreset.description,
                    trackConfigurations: supabasePreset.track_configurations
                )
            }
        } catch {
            print("ℹ️ Using sample presets: \(error.localizedDescription)")
            return samplePresets()
        }
    }
    
    // MARK: - Helper: Icon Mapping
    private func iconForTrack(name: String, category: String) -> String {
        let nameLower = name.lowercased()
        
        // Map common names to SF Symbols
        if nameLower.contains("ocean") || nameLower.contains("wave") {
            return "waveform"
        } else if nameLower.contains("rain") {
            return "cloud.rain.fill"
        } else if nameLower.contains("wind") || nameLower.contains("tree") {
            return "tree.fill"
        } else if nameLower.contains("bird") {
            return "bird.fill"
        } else if nameLower.contains("thunder") || nameLower.contains("storm") {
            return "cloud.bolt.fill"
        } else if nameLower.contains("river") || nameLower.contains("water") {
            return "water.waves"
        } else if nameLower.contains("fire") || nameLower.contains("fireplace") {
            return "flame.fill"
        } else if nameLower.contains("cafe") || nameLower.contains("coffee") {
            return "cup.and.saucer.fill"
        } else if nameLower.contains("clock") || nameLower.contains("tick") {
            return "clock.fill"
        } else if nameLower.contains("bowl") || nameLower.contains("meditation") {
            return "music.note"
        }
        
        // Default icons by category
        return category == "nature" ? "leaf.fill" : "house.fill"
    }
    
    // MARK: - Sample Data (Fallback)
    static func sampleAudioTracks() -> [AudioTrack] {
        return [
            // Nature sounds
            AudioTrack(
                name: "Birds Chirping",
                category: "nature",
                icon: "bird.fill",
                description: nil,
                audioUrl: "\(SupabaseConfig.storageURL)/object/public/ambient-sounds/nature/birds.m4a"
            ),
            AudioTrack(
                name: "Ocean Waves",
                category: "nature",
                icon: "waveform",
                description: nil,
                audioUrl: "\(SupabaseConfig.storageURL)/object/public/ambient-sounds/nature/ocean.m4a"
            ),
            AudioTrack(
                name: "Rain",
                category: "nature",
                icon: "cloud.rain.fill",
                description: nil,
                audioUrl: "\(SupabaseConfig.storageURL)/object/public/ambient-sounds/nature/rain.m4a"
            ),
            AudioTrack(
                name: "River",
                category: "nature",
                icon: "water.waves",
                description: nil,
                audioUrl: "\(SupabaseConfig.storageURL)/object/public/ambient-sounds/nature/river.m4a"
            ),
            AudioTrack(
                name: "Distant Thunder",
                category: "nature",
                icon: "cloud.bolt.fill",
                description: nil,
                audioUrl: "\(SupabaseConfig.storageURL)/object/public/ambient-sounds/nature/thunder.m4a"
            ),
            AudioTrack(
                name: "Wind in Trees",
                category: "nature",
                icon: "tree.fill",
                description: nil,
                audioUrl: "\(SupabaseConfig.storageURL)/object/public/ambient-sounds/nature/wind.m4a"
            ),
            // Indoor sounds
            AudioTrack(
                name: "Fireplace",
                category: "indoor",
                icon: "flame.fill",
                description: nil,
                audioUrl: "\(SupabaseConfig.storageURL)/object/public/ambient-sounds/indoor/fireplace.m4a"
            ),
            AudioTrack(
                name: "Tibetan Bowls",
                category: "indoor",
                icon: "music.note",
                description: nil,
                audioUrl: "\(SupabaseConfig.storageURL)/object/public/ambient-sounds/indoor/tibetan-bowl.m4a"
            )
        ]
    }
    
    private func samplePresets() -> [Preset] {
        return [
            Preset(
                name: "Rainy Day",
                icon: "cloud.rain.fill",
                description: "Perfect for cozy focus.",
                trackConfigurations: [
                    "Rain": 0.8,
                    "Wind in Trees": 0.3
                ]
            ),
            Preset(
                name: "Ocean Breeze",
                icon: "waveform",
                description: "Coastal relaxation.",
                trackConfigurations: [
                    "Ocean Waves": 0.9,
                    "Wind in Trees": 0.4
                ]
            )
        ]
    }
    
    // MARK: - Upload Recording
    func uploadRecording(
        fileURL: URL,
        accessToken: String,
        userId: UUID,
        title: String,
        category: String,
        description: String?,
        icon: String,
        duration: TimeInterval,
        fileSize: Int64,
        locationName: String?,
        latitude: Double?,
        longitude: Double?
    ) async throws -> AudioTrack {
        // Generate recording ID
        let recordingId = UUID()
        
        // Construct file path: {user_id}/{recording_id}.m4a
        // This matches: supabase.storage.from("user-recordings").upload(`${user.id}/${filename}`, fileBlob)
        let fileName = "\(recordingId.uuidString).m4a"
        let filePath = "\(userId.uuidString)/\(fileName)"
        
        // Upload file to storage using REST API
        // Endpoint: POST /storage/v1/object/{bucket}/{user_id}/{filename}
        // URL encode each path component separately
        let encodedUserId = userId.uuidString.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId.uuidString
        let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
        let storageURL = URL(string: "\(SupabaseConfig.storageURL)/object/user-recordings/\(encodedUserId)/\(encodedFileName)")!
        
        var uploadRequest = URLRequest(url: storageURL)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        uploadRequest.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        uploadRequest.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
        uploadRequest.setValue("binary", forHTTPHeaderField: "x-upsert") // Upsert if exists
        
        // Read file data
        let fileData = try Data(contentsOf: fileURL)
        uploadRequest.httpBody = fileData
        
        // Upload file
        print("📤 Starting file upload to: \(storageURL)")
        print("📤 File size: \(fileData.count) bytes")
        
        let (uploadData, uploadResponse) = try await urlSession.data(for: uploadRequest)
        
        guard let httpResponse = uploadResponse as? HTTPURLResponse else {
            print("❌ Invalid response type from file upload")
            throw SupabaseError.invalidResponse
        }
        
        print("📤 File upload response: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: uploadData, encoding: .utf8) ?? "Unknown error"
            print("❌ Failed to upload recording FILE: \(httpResponse.statusCode) - \(errorMessage)")
            print("❌ Upload response headers: \(httpResponse.allHeaderFields)")
            
            // Check if error message indicates token expiration
            let isTokenExpired = errorMessage.contains("exp") && 
                                (errorMessage.contains("claim") || errorMessage.contains("timestamp"))
            
            // Parse error to provide better message
            if errorMessage.contains("Bucket not found") {
                throw SupabaseError.bucketNotFound
            } else if httpResponse.statusCode == 401 || isTokenExpired {
                // Token expiration errors (even if HTTP status is 400) should be treated as auth errors
                throw SupabaseError.unauthorized
            } else if httpResponse.statusCode == 403 {
                throw SupabaseError.forbidden
            } else {
                throw SupabaseError.networkError(errorMessage)
            }
        }
        
        print("✅ Successfully uploaded recording to: \(filePath)")
        print("📝 Now attempting database insert...")
        
        // Create database entry using insert_user_recording function
        // This function uses SECURITY DEFINER to bypass RLS policies
        let functionURL = URL(string: "\(SupabaseConfig.apiURL)/rpc/insert_user_recording")!
        print("📝 Function URL constructed: \(functionURL)")
        var functionRequest = createRequest(url: functionURL, method: "POST", accessToken: accessToken)
        functionRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        // Prepare function parameters
        // The function will automatically set user_id from auth.uid()
        var payload: [String: Any] = [
            "p_id": recordingId.uuidString,
            "p_file_path": filePath,
            "p_duration_seconds": Int(duration),  // Convert to integer seconds
            "p_name": title,
            "p_category": category,
            "p_icon": icon
        ]
        
        // Add optional fields if provided
        if let description = description {
            payload["p_description"] = description
        }
        if let locationName = locationName {
            payload["p_location_name"] = locationName
        }
        if let latitude = latitude {
            payload["p_latitude"] = latitude
        }
        if let longitude = longitude {
            payload["p_longitude"] = longitude
        }
        
        functionRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        print("🔧 Calling insert_user_recording function")
        print("🔧 Function URL: \(functionURL)")
        print("🔧 Payload: \(payload)")
        print("🔧 Access token present: \(accessToken.isEmpty ? "NO" : "YES")")
        
        // Call the function
        let (dbData, dbResponse) = try await urlSession.data(for: functionRequest)
        
        guard let dbHttpResponse = dbResponse as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        let responseBody = String(data: dbData, encoding: .utf8) ?? "Unknown"
        print("🔧 Function response status: \(dbHttpResponse.statusCode)")
        print("🔧 Function response body: \(responseBody)")
        
        if (200...299).contains(dbHttpResponse.statusCode) {
            print("✅ Successfully created database entry via function")
            // Delay to ensure database transaction is committed and replicated
            // Supabase uses read replicas, so we need to wait for replication
            // Increased delay to handle eventual consistency
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
            print("⏳ Waited 2 seconds for database commit/replication")
        } else {
            let errorMessage = responseBody
            print("❌ Failed to create database entry via function: \(dbHttpResponse.statusCode)")
            print("❌ Error: \(errorMessage)")
            
            // If function doesn't exist (404), fall back to direct insert
            if dbHttpResponse.statusCode == 404 {
                print("⚠️ Function not found, trying direct insert as fallback...")
                
                // Fallback: Direct insert
                let dbURL = URL(string: "\(SupabaseConfig.apiURL)/user_recordings")!
                var dbRequest = createRequest(url: dbURL, method: "POST", accessToken: accessToken)
                dbRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
                
                let directPayload: [String: Any] = [
                    "id": recordingId.uuidString,
                    "user_id": userId.uuidString,
                    "file_path": filePath,
                    "duration_seconds": Int(duration)
                ]
                
                dbRequest.httpBody = try JSONSerialization.data(withJSONObject: directPayload)
                
                let (fallbackData, fallbackResponse) = try await urlSession.data(for: dbRequest)
                
                guard let fallbackHttpResponse = fallbackResponse as? HTTPURLResponse else {
                    throw SupabaseError.invalidResponse
                }
                
                guard (200...299).contains(fallbackHttpResponse.statusCode) else {
                    let fallbackError = String(data: fallbackData, encoding: .utf8) ?? "Unknown error"
                    print("❌ Direct insert also failed: \(fallbackHttpResponse.statusCode) - \(fallbackError)")
                    throw SupabaseError.networkError(fallbackError)
        }
        
                print("✅ Successfully created database entry via direct insert fallback")
            } else {
                // Use errorMessage which already contains the response body, or dbData if needed
                let errorMsg = errorMessage.isEmpty ? (String(data: dbData, encoding: .utf8) ?? "Unknown error") : errorMessage
                throw SupabaseError.networkError(errorMsg)
            }
        }
        
        // Construct audio URL for playback
        let audioUrl = "\(SupabaseConfig.storageURL)/object/public/user-recordings/\(filePath)"
        print("🎵 Constructed audio URL for playback: \(audioUrl)")
        print("🎵 Storage URL base: \(SupabaseConfig.storageURL)")
        print("🎵 File path: \(filePath)")
        
        // Return AudioTrack
        return AudioTrack(
            id: recordingId,
            name: title,
            category: category,
            icon: icon,
            description: description,
            audioUrl: audioUrl,
            trackType: .audioFile,
            isActive: false,
            volume: 0.0,
            isUserRecording: true,
            userId: userId,
            recordedAt: Date(),
            duration: duration,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude
        )
    }
    
    // MARK: - Fetch User Recordings (for authenticated users)
    func fetchUserRecordings(accessToken: String, userId: UUID, recordingId: UUID? = nil) async throws -> [AudioTrack] {
        // Explicitly filter out deleted recordings (deleted_at IS NULL)
        // RLS policy should also handle this, but we add explicit filter for safety
        var urlString = "\(SupabaseConfig.apiURL)/user_recordings?user_id=eq.\(userId.uuidString)&deleted_at=is.null&select=*&order=created_at.desc"
        
        // If a specific recording ID is provided, filter by it
        if let id = recordingId {
            urlString += "&id=eq.\(id.uuidString)"
        }
        
        let url = URL(string: urlString)!
        var request = createRequest(url: url, method: "GET", accessToken: accessToken)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        print("🔍 Fetching user recordings from: \(urlString)")
        if let id = recordingId {
            print("🔍 Targeting specific recording: \(id.uuidString)")
        }
        print("🔍 User ID: \(userId.uuidString)")
        print("🔍 Explicitly filtering deleted_at IS NULL (non-deleted recordings only)")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseError.invalidResponse
            }
            
            print("🔍 Response status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
                print("⚠️ Failed to fetch user recordings: \(httpResponse.statusCode)")
                print("⚠️ Error body: \(errorBody)")
                return [] // Return empty array if table doesn't exist or error
            }
            
            let responseBody = String(data: data, encoding: .utf8) ?? "Empty"
            print("🔍 Response body: \(responseBody)")
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let userRecordings = try decoder.decode([SupabaseUserRecording].self, from: data)
            
            print("✅ Successfully fetched \(userRecordings.count) user recordings from API")
            print("📋 Raw recording IDs from API: \(userRecordings.map { "\($0.name ?? "nil") (\($0.id.prefix(8)))" }.joined(separator: ", "))")
            
            // IMPORTANT: Double-check that we don't have any deleted recordings
            // This is a safety measure in case the query filter didn't work
            let activeRecordings = userRecordings.filter { recording in
                if let deletedAt = recording.deleted_at, !deletedAt.isEmpty {
                    print("⚠️ WARNING: Found deleted recording in fetch results: \(recording.name ?? "unknown") (deleted_at: \(deletedAt))")
                    return false
                }
                return true
            }
            
            if activeRecordings.count != userRecordings.count {
                print("⚠️ WARNING: Query returned \(userRecordings.count - activeRecordings.count) deleted recording(s) that should have been filtered!")
            }
            
            print("✅ Filtered to \(activeRecordings.count) active (non-deleted) recordings")
            
            // Convert to AudioTrack format, filtering out any nil results
            let audioTracks: [AudioTrack] = activeRecordings.compactMap { recording in
                // Construct storage URL
                let audioUrl = "\(SupabaseConfig.storageURL)/object/public/user-recordings/\(recording.file_path)"
                print("🎵 Loading user recording: \(recording.name)")
                print("🎵 Audio URL: \(audioUrl)")
                print("🎵 File path from DB: \(recording.file_path)")
                
                // Parse dates - use recorded_at if available, otherwise fallback to created_at
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let recordedAt = recording.recorded_at.flatMap { formatter.date(from: $0) }
                    ?? recording.created_at.flatMap { formatter.date(from: $0) }
                
                // Provide defaults for nullable fields
                let recordingName = recording.name ?? "Untitled Recording"
                let recordingCategory = recording.category ?? "My Recordings"
                
                // Convert duration_seconds to TimeInterval
                let duration: TimeInterval? = recording.duration_seconds.map { TimeInterval($0) }
                
                guard let recordingUUID = UUID(uuidString: recording.id) else {
                    print("⚠️ Invalid UUID format for recording: \(recording.id)")
                    // Skip this recording if UUID is invalid
                    return nil
                }
                
                return AudioTrack(
                    id: recordingUUID,
                    name: recordingName,
                    category: recordingCategory,
                    icon: recording.icon ?? iconForTrack(name: recordingName, category: recordingCategory),
                    description: recording.description,
                    audioUrl: audioUrl,
                    trackType: .audioFile,
                    isActive: false,
                    volume: 0.0,
                    isUserRecording: true,
                    userId: UUID(uuidString: recording.user_id),
                    recordedAt: recordedAt,
                    duration: duration,
                    locationName: recording.location_name,
                    latitude: recording.latitude,
                    longitude: recording.longitude
                )
            }
            
            print("✅ Converted to \(audioTracks.count) AudioTrack objects")
            print("📋 Final AudioTrack IDs: \(audioTracks.map { "\($0.name) (\($0.id.uuidString.prefix(8)))" }.joined(separator: ", "))")
            
            return audioTracks
        } catch {
            print("⚠️ Error fetching user recordings: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                print("⚠️ Decoding error details: \(decodingError)")
            }
            return []
        }
    }
    
    // MARK: - Update User Recording
    func updateUserRecording(
        accessToken: String,
        recordingId: UUID,
        name: String,
        category: String,
        description: String?,
        icon: String
    ) async throws {
        // Use the update_user_recording function via RPC for better reliability
        let functionURL = URL(string: "\(SupabaseConfig.apiURL)/rpc/update_user_recording")!
        var functionRequest = createRequest(url: functionURL, method: "POST", accessToken: accessToken)
        functionRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
        functionRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: Any] = [
            "p_id": recordingId.uuidString,
            "p_name": name,
            "p_category": category,
            "p_icon": icon
        ]
        
        if let description = description {
            payload["p_description"] = description
        } else {
            payload["p_description"] = NSNull()
        }
        
        functionRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        print("🔧 Updating recording via function: \(recordingId)")
        print("🔧 Function URL: \(functionURL)")
        print("🔧 Payload: \(payload)")
        NSLog("🔧 UPDATE: Recording ID: %@, URL: %@", recordingId.uuidString, functionURL.absoluteString)
        NSLog("🔧 UPDATE: Payload: %@", String(describing: payload))
        
        let (data, response) = try await urlSession.data(for: functionRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        let responseBody = String(data: data, encoding: .utf8) ?? "Unknown"
        print("🔧 Update response status: \(httpResponse.statusCode)")
        print("🔧 Update response body: \(responseBody)")
        NSLog("🔧 UPDATE RESPONSE: Status %d", httpResponse.statusCode)
        NSLog("🔧 UPDATE RESPONSE BODY: %@", responseBody)
        
        // Check for JWT expiration
        if httpResponse.statusCode == 401 {
            let errorMessage = responseBody.lowercased()
            if errorMessage.contains("jwt") && (errorMessage.contains("expired") || errorMessage.contains("exp")) {
                print("⚠️ JWT expired during update, throwing unauthorized error")
                throw SupabaseError.unauthorized
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Parse error response for better error message
            var errorDetails = "HTTP \(httpResponse.statusCode)"
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let message = errorData["message"] as? String {
                    errorDetails = message
                } else if let error = errorData["error"] as? String {
                    errorDetails = error
                } else if let code = errorData["code"] as? String {
                    errorDetails = "\(code): \(responseBody)"
                }
            }
            
            print("❌ Failed to update recording: \(httpResponse.statusCode)")
            print("❌ Error details: \(errorDetails)")
            print("❌ Full response: \(responseBody)")
            
            // Handle "Recording not found" - for updates, this is an error (unlike delete which is idempotent)
            if httpResponse.statusCode == 400 && responseBody.lowercased().contains("recording not found") {
                print("❌ Recording not found - cannot update non-existent recording")
                NSLog("❌ UPDATE ERROR: Recording not found - ID: %@", recordingId.uuidString)
                // Create a more specific error
                throw SupabaseError.networkError("Recording not found. The recording may have been deleted.")
            }
            
            NSLog("❌ UPDATE ERROR: HTTP %d, Details: %@", httpResponse.statusCode, errorDetails)
            throw SupabaseError.networkError(errorDetails)
        }
        
        print("✅ Successfully updated recording: \(recordingId)")
        NSLog("✅ UPDATE SUCCESS: Recording ID: %@", recordingId.uuidString)
    }
    
    // MARK: - Delete User Recording
    func deleteUserRecording(accessToken: String, recordingId: UUID) async throws {
        // Use the delete_user_recording function via RPC for better reliability
        let functionURL = URL(string: "\(SupabaseConfig.apiURL)/rpc/delete_user_recording")!
        var functionRequest = createRequest(url: functionURL, method: "POST", accessToken: accessToken)
        functionRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
        functionRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "p_id": recordingId.uuidString
        ]
        
        functionRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        print("🗑️ Deleting recording via function: \(recordingId)")
        print("🗑️ Function URL: \(functionURL)")
        print("🗑️ Payload: \(payload)")
        NSLog("🗑️ DELETE: Recording ID: %@, URL: %@", recordingId.uuidString, functionURL.absoluteString)
        NSLog("🗑️ DELETE: Payload: %@", String(describing: payload))
        
        let (dbData, dbResponse) = try await urlSession.data(for: functionRequest)
        
        guard let dbHttpResponse = dbResponse as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        let responseBody = String(data: dbData, encoding: .utf8) ?? "Unknown"
        print("🗑️ Delete response status: \(dbHttpResponse.statusCode)")
        print("🗑️ Delete response body: \(responseBody)")
        NSLog("🗑️ DELETE RESPONSE: Status %d", dbHttpResponse.statusCode)
        NSLog("🗑️ DELETE RESPONSE BODY: %@", responseBody)
        
        // Check for JWT expiration
        if dbHttpResponse.statusCode == 401 {
            let errorMessage = responseBody.lowercased()
            if errorMessage.contains("jwt") && (errorMessage.contains("expired") || errorMessage.contains("exp")) {
                print("⚠️ JWT expired during delete, throwing unauthorized error")
                throw SupabaseError.unauthorized
            }
        }
        
        // Handle "Recording not found" as success (idempotent delete)
        // If the recording doesn't exist, the goal is achieved - it's already deleted
        if dbHttpResponse.statusCode == 400 {
            // Parse the error response to check if it's "Recording not found"
            if let errorData = try? JSONSerialization.jsonObject(with: dbData) as? [String: Any],
               let message = errorData["message"] as? String,
               message.lowercased().contains("recording not found") {
                print("ℹ️ Recording not found - treating as successful deletion (already deleted)")
                print("✅ Recording was already deleted or doesn't exist: \(recordingId)")
                return // Success - recording is already gone
            }
        }
        
        guard (200...299).contains(dbHttpResponse.statusCode) else {
            // Parse error response for better error message
            var errorDetails = "HTTP \(dbHttpResponse.statusCode)"
            if let errorData = try? JSONSerialization.jsonObject(with: dbData) as? [String: Any] {
                if let message = errorData["message"] as? String {
                    errorDetails = message
                } else if let error = errorData["error"] as? String {
                    errorDetails = error
                } else if let code = errorData["code"] as? String {
                    errorDetails = "\(code): \(responseBody)"
                }
            }
            
            print("❌ Failed to delete recording from database: \(dbHttpResponse.statusCode)")
            print("❌ Error details: \(errorDetails)")
            print("❌ Full response: \(responseBody)")
            
            // Handle "Recording not found" as success (idempotent delete)
            if dbHttpResponse.statusCode == 400 && responseBody.lowercased().contains("recording not found") {
                print("ℹ️ Recording not found - treating as successful deletion (already deleted)")
                print("✅ Recording was already deleted or doesn't exist: \(recordingId)")
                return // Success - recording is already gone
            }
            
            throw SupabaseError.networkError(errorDetails)
        }
        
        print("✅ Successfully deleted recording from database: \(recordingId)")
        NSLog("✅ DELETE SUCCESS: Recording ID: %@", recordingId.uuidString)
        
        // Note: Storage file deletion would require additional API call
        // For now, we'll just delete the database entry
        // TODO: Add storage file deletion if needed
    }
}

// MARK: - Supabase Data Models
private struct SupabaseAmbientSound: Codable {
    let id: String
    let name: String
    let category: String
    let file_path: String
    let file_size: Int?
    let duration: Double?
    let created_at: String?
    let updated_at: String?
}

private struct SupabasePreset: Codable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let track_configurations: [String: Double]
    let created_at: String?
}

private struct SupabaseUserRecording: Codable {
    let id: String
    let user_id: String
    let name: String?
    let category: String?
    let file_path: String
    let duration_seconds: Int?
    let file_size: Int?
    let description: String?
    let icon: String?
    let location_name: String?
    let latitude: Double?
    let longitude: Double?
    let recorded_at: String?
    let created_at: String?
    let updated_at: String?
    let deleted_at: String?  // Add deleted_at to verify filtering
    
    // Computed property to convert duration_seconds to Double
    var duration: Double? {
        guard let seconds = duration_seconds else { return nil }
        return Double(seconds)
    }
}

// MARK: - Errors
enum SupabaseError: LocalizedError {
    case invalidResponse
    case decodingError
    case networkError(String?)
    case bucketNotFound
    case unauthorized
    case forbidden
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let details):
            if let details = details, !details.isEmpty {
                return "Network error: \(details)"
            }
            return "Network error occurred. Please check your connection and try again."
        case .bucketNotFound:
            return "Recording storage is not set up yet. The 'user-recordings' bucket needs to be created in Supabase. See SUPABASE_RECORDING_SETUP.md for setup instructions."
        case .unauthorized:
            return "Authentication failed. Please sign in again."
        case .forbidden:
            return "You don't have permission to perform this action."
        }
    }
}
