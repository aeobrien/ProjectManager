import Foundation
import AVFoundation

// Define a tuple to hold both transcriptions
typealias TranscriptionResultTuple = (original: String?, final: String)

// The TranscriptionService handles communication with transcription APIs
class TranscriptionService {
    typealias StatusUpdateHandler = ((String) -> Void)
    
    // MARK: - Transcription Persistence
    
    private var transcriptionsFolder: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let transcriptionsPath = documentsPath.appendingPathComponent("SavedTranscriptions")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: transcriptionsPath.path) {
            try? FileManager.default.createDirectory(at: transcriptionsPath, withIntermediateDirectories: true)
        }
        
        return transcriptionsPath
    }
    
    private func saveTranscription(_ transcription: String, fileName: String) {
        let timestamp = Date().formatted(date: .abbreviated, time: .complete)
        let content = """
        # Saved Transcription - \(timestamp)
        
        Original Audio File: \(fileName)
        
        ## Transcription:
        \(transcription)
        
        ---
        This transcription was automatically saved after a timeout or error occurred during processing.
        You can copy this text and paste it into the "New Project" form to manually create your project.
        """
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileTimestamp = dateFormatter.string(from: Date())
        
        let saveFileName = "transcription_\(fileTimestamp).md"
        let saveURL = transcriptionsFolder.appendingPathComponent(saveFileName)
        
        do {
            try content.write(to: saveURL, atomically: true, encoding: .utf8)
            print("✅ Saved transcription to: \(saveURL.path)")
        } catch {
            print("❌ Failed to save transcription: \(error)")
        }
    }
    
    func getSavedTranscriptions() -> [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: transcriptionsFolder, includingPropertiesForKeys: [.creationDateKey])
            return files.filter { $0.pathExtension == "md" }.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
        } catch {
            print("Error getting saved transcriptions: \(error)")
            return []
        }
    }
    
    // Static default prompt for GPT processing
    private static let defaultGPTPrompt = "You are a helpful assistant processing a voice recording. Organize the transcribed content into clear, well-formatted text. Fix any obvious transcription errors, improve readability, and maintain the original meaning. Do not add any new information that wasn't in the original content."
    
    // MARK: - API Configuration
    
    private let apiKey = "" // Replace with actual API key or use secure storage
    private let transcriptionEndpoint = "https://api.openai.com/v1/audio/transcriptions"
    private let chatCompletionEndpoint = "https://api.openai.com/v1/chat/completions"
    
    // MARK: - Transcription Errors
    
    enum TranscriptionError: LocalizedError {
        case invalidEndpoint
        case invalidResponse
        case noData
        case parsingFailed
        case apiError(message: String)
        case serverError(statusCode: Int)
        case fileTooLarge(sizeMB: Double)
        
        var errorDescription: String? {
            switch self {
            case .invalidEndpoint:
                return "Invalid API endpoint"
            case .invalidResponse:
                return "Invalid response from server"
            case .noData:
                return "No data received from server"
            case .parsingFailed:
                return "Failed to parse server response"
            case .apiError(let message):
                return "API Error: \(message)"
            case .serverError(let statusCode):
                return "Server Error: HTTP \(statusCode)"
            case .fileTooLarge(let sizeMB):
                return "Audio file is too large (\(String(format: "%.1f", sizeMB))MB). Maximum size is 25MB."
            }
        }
    }
    
    func transcribeAudio(
        fileURL: URL,
        requiresSecondAPICall: Bool = false,
        promptForSecondCall: String = TranscriptionService.defaultGPTPrompt,
        statusUpdate: StatusUpdateHandler? = nil,
        completion: @escaping (Result<TranscriptionResultTuple, Error>) -> Void
    ) {
        // Validate audio file size
        var fileSizeMB: Double = 0
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            fileSizeMB = Double(fileSize) / 1024 / 1024
            print("Audio file size: \(fileSizeMB) MB")
            
            // Check if file is larger than 25MB (OpenAI's limit)
            if fileSizeMB > 25 {
                print("Error: File size (\(fileSizeMB)MB) exceeds OpenAI's 25MB limit")
                statusUpdate?("Error: File too large (\(String(format: "%.1f", fileSizeMB))MB)")
                completion(.failure(TranscriptionError.fileTooLarge(sizeMB: fileSizeMB)))
                return
            }
        } catch {
            print("Error checking file size: \(error.localizedDescription)")
        }
        
        guard let url = URL(string: transcriptionEndpoint) else {
            completion(.failure(TranscriptionError.invalidEndpoint))
            return
        }

        let fileName = fileURL.lastPathComponent
        print("Transcribing file: \(fileName), size: \(fileSizeMB)MB")
        statusUpdate?(requiresSecondAPICall ? 
            "Step 1/2: Preparing audio file (\(fileName)) for transcription..." : 
            "Preparing audio file (\(fileName)) for transcription...")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 600 // 10 minutes timeout for large files
        
        // Create multipart form data
        request.httpBody = createMultipartBody(
            fileURL: fileURL,
            model: "whisper-1",
            prompt: "",
            boundary: boundary
        )
        
        statusUpdate?(requiresSecondAPICall ?
            "Step 1/2: Sending audio to OpenAI for transcription..." :
            "Sending audio to OpenAI for transcription...")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                let errorDescription = error.localizedDescription
                statusUpdate?("Network error: \(errorDescription)")
                
                // Check if it's a timeout error
                if errorDescription.contains("timed out") || errorDescription.contains("timeout") {
                    statusUpdate?("Request timed out. Unfortunately, we cannot save the transcription as it wasn't completed.")
                }
                
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                statusUpdate?("Invalid response received")
                completion(.failure(TranscriptionError.invalidResponse))
                return
            }
            
            print("HTTP Status Code: \(httpResponse.statusCode)")
            statusUpdate?(requiresSecondAPICall ?
                "Step 1/2: Received response from OpenAI (Status: \(httpResponse.statusCode))" :
                "Received response from OpenAI (Status: \(httpResponse.statusCode))")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                    statusUpdate?("API error: \(errorMessage)")
                    completion(.failure(TranscriptionError.apiError(message: errorMessage)))
                } else {
                    statusUpdate?("Server error: \(httpResponse.statusCode)")
                    completion(.failure(TranscriptionError.serverError(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            guard let data = data else {
                statusUpdate?("No data received from server")
                completion(.failure(TranscriptionError.noData))
                return
            }
            
            do {
                statusUpdate?(requiresSecondAPICall ?
                    "Step 1/2: Processing initial transcription response..." :
                    "Processing transcription response...")
                print("Whisper API raw response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let initialTranscription = json["text"] as? String {
                    print("Extracted transcription: '\(initialTranscription)' (length: \(initialTranscription.count))")
                    
                    if requiresSecondAPICall {
                        statusUpdate?("Step 1/2: Complete! Moving to step 2...")
                        print("About to call processTranscription with text: \(initialTranscription.prefix(100))...")
                        
                        // Small delay to ensure UI updates
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            statusUpdate?("Step 2/2: Preparing to process with instructions...")
                            print("Calling processTranscription now...")
                            self?.processTranscription(
                                initialTranscription: initialTranscription,
                                prompt: promptForSecondCall,
                                statusUpdate: statusUpdate,
                                completion: completion,
                                originalFileName: fileName
                            )
                        }
                    } else {
                        statusUpdate?("Transcription complete!")
                        completion(.success((original: nil, final: initialTranscription)))
                    }
                } else {
                    statusUpdate?("Failed to parse transcription response")
                    completion(.failure(TranscriptionError.parsingFailed))
                }
            } catch {
                statusUpdate?("Error decoding response: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    private func processTranscription(
        initialTranscription: String,
        prompt: String,
        statusUpdate: StatusUpdateHandler?,
        completion: @escaping (Result<TranscriptionResultTuple, Error>) -> Void,
        originalFileName: String = "unknown"
    ) {
        print("processTranscription called with transcription length: \(initialTranscription.count)")
        print("Prompt length: \(prompt.count)")
        
        guard let url = URL(string: chatCompletionEndpoint) else {
            print("Invalid chatCompletionEndpoint: \(chatCompletionEndpoint)")
            completion(.failure(TranscriptionError.invalidEndpoint))
            return
        }
        
        print("GPT endpoint URL valid: \(url)")
        statusUpdate?("Step 2/2: Preparing instruction processing request...")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300 // 5 minutes timeout for GPT processing
        
        let messages = [
            ["role": "system", "content": prompt],
            ["role": "user", "content": initialTranscription]
        ]
        
        let body: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 4000
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("GPT request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "Unable to decode")")
            statusUpdate?("Step 2/2: Sending to GPT for processing...")
        } catch {
            statusUpdate?("Error preparing request: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("GPT Network error: \(error)")
                let errorDescription = error.localizedDescription
                statusUpdate?("GPT processing failed: \(errorDescription)")
                
                // Save transcription if GPT processing fails
                if errorDescription.contains("timed out") || errorDescription.contains("timeout") {
                    statusUpdate?("GPT processing timed out. Saving transcription for manual processing...")
                    self?.saveTranscription(initialTranscription, fileName: originalFileName)
                    statusUpdate?("Transcription saved! Check Documents/SavedTranscriptions folder.")
                } else {
                    statusUpdate?("GPT processing failed. Saving transcription for manual processing...")
                    self?.saveTranscription(initialTranscription, fileName: originalFileName)
                    statusUpdate?("Transcription saved! Check Documents/SavedTranscriptions folder.")
                }
                
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("GPT Invalid response received")
                statusUpdate?("Invalid response received")
                completion(.failure(TranscriptionError.invalidResponse))
                return
            }
            
            print("GPT HTTP Status Code: \(httpResponse.statusCode)")
            statusUpdate?("Step 2/2: Received response (Status: \(httpResponse.statusCode))")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Save transcription for any non-success status code
                statusUpdate?("GPT API error (Status: \(httpResponse.statusCode)). Saving transcription...")
                self?.saveTranscription(initialTranscription, fileName: originalFileName)
                statusUpdate?("Transcription saved! Check Documents/SavedTranscriptions folder.")
                
                if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                    print("GPT API error: \(errorMessage)")
                    completion(.failure(TranscriptionError.apiError(message: errorMessage)))
                } else {
                    print("GPT Server error: \(httpResponse.statusCode)")
                    completion(.failure(TranscriptionError.serverError(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            guard let data = data else {
                statusUpdate?("No data received from GPT. Saving transcription...")
                self?.saveTranscription(initialTranscription, fileName: originalFileName)
                statusUpdate?("Transcription saved! Check Documents/SavedTranscriptions folder.")
                completion(.failure(TranscriptionError.noData))
                return
            }
            
            do {
                statusUpdate?("Step 2/2: Processing final response...")
                print("GPT Raw response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let processedText = message["content"] as? String {
                    
                    print("GPT Processing successful, response length: \(processedText.count)")
                    statusUpdate?("Processing complete! Both steps finished.")
                    completion(.success((original: initialTranscription, final: processedText)))
                } else {
                    print("GPT Failed to parse response structure")
                    statusUpdate?("Failed to parse GPT response. Saving transcription...")
                    self?.saveTranscription(initialTranscription, fileName: originalFileName)
                    statusUpdate?("Transcription saved! Check Documents/SavedTranscriptions folder.")
                    completion(.failure(TranscriptionError.parsingFailed))
                }
            } catch {
                print("GPT Error decoding response: \(error)")
                statusUpdate?("Error decoding GPT response. Saving transcription...")
                self?.saveTranscription(initialTranscription, fileName: originalFileName)
                statusUpdate?("Transcription saved! Check Documents/SavedTranscriptions folder.")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    private func createMultipartBody(fileURL: URL, model: String, prompt: String, boundary: String) -> Data? {
        var body = Data()
        
        do {
            let audioData = try Data(contentsOf: fileURL)
            
            // Add model parameter
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(model)\r\n".data(using: .utf8)!)
            
            // Add prompt parameter if not empty
            if !prompt.isEmpty {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(prompt)\r\n".data(using: .utf8)!)
            }
            
            // Add audio file
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
            
            // Set appropriate content type based on file extension
            let contentType = fileURL.pathExtension.lowercased() == "m4a" ? "audio/mp4" : "audio/wav"
            body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n".data(using: .utf8)!)
            
            // Close boundary
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            return body
        } catch {
            print("Error creating multipart body: \(error)")
            return nil
        }
    }
}
