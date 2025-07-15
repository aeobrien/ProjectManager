import SwiftUI
import AVFoundation
import Foundation
import ProjectManagerCore

struct NewProjectForm: View {
    @ObservedObject var projectsManager: ProjectsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var projectName = ""
    @State private var coreConcept = ""
    @State private var guidingPrinciples = ""
    @State private var keyFeatures = ""
    @State private var architecture = ""
    @State private var implementationRoadmap = ""
    @State private var currentStatus = ""
    @State private var nextSteps = ""
    @State private var challenges = ""
    @State private var userExperience = ""
    @State private var successMetrics = ""
    @State private var research = ""
    @State private var openQuestions = ""
    @State private var externalFiles = ""
    @State private var repositories = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Voice input state
    @State private var showingVoiceInput = false
    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var audioLevel: Float = 0
    @State private var processingStatus = "Ready to record"
    @State private var isProcessing = false
    
    // Text input state
    @State private var inputMode: InputMode = .voice
    @State private var textInput = ""
    
    enum InputMode: String, CaseIterable {
        case voice = "Voice"
        case text = "Text"
    }
    
    // Audio recording properties
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var recordingStartTime: Date?
    
    @State private var durationTimer: Timer?
    @State private var audioLevelTimer: Timer?
    @State private var transcriptionService: TranscriptionService?
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Text("New Project")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Project Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Project Name")
                                .font(.headline)
                            TextField("Enter project name...", text: $projectName)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // Core Concept
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Core Concept")
                                .font(.headline)
                            TextEditor(text: $coreConcept)
                                .frame(minHeight: 80)
                                .overlay(
                                    Group {
                                        if coreConcept.isEmpty {
                                            Text("What is this project and its primary purpose?")
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        
                        // Guiding Principles
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Guiding Principles & Intentions")
                                .font(.headline)
                            TextEditor(text: $guidingPrinciples)
                                .frame(minHeight: 60)
                                .overlay(
                                    Group {
                                        if guidingPrinciples.isEmpty {
                                            Text("Philosophy, values, and goals driving the project")
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        
                        // Key Features
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Key Features & Functionality")
                                .font(.headline)
                            TextEditor(text: $keyFeatures)
                                .frame(minHeight: 80)
                                .overlay(
                                    Group {
                                        if keyFeatures.isEmpty {
                                            Text("List the main features or components...")
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        
                        // Architecture
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Architecture & Structure")
                                .font(.headline)
                            TextEditor(text: $architecture)
                                .frame(minHeight: 60)
                                .overlay(
                                    Group {
                                        if architecture.isEmpty {
                                            Text("Technical architecture or organizational structure...")
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        
                        // Implementation Roadmap
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Implementation Roadmap")
                                .font(.headline)
                            TextEditor(text: $implementationRoadmap)
                                .frame(minHeight: 80)
                                .overlay(
                                    Group {
                                        if implementationRoadmap.isEmpty {
                                            Text("Phase-by-phase implementation plan...")
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        
                        // Current Status
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Status & Progress")
                                .font(.headline)
                            TextEditor(text: $currentStatus)
                                .frame(minHeight: 60)
                                .overlay(
                                    Group {
                                        if currentStatus.isEmpty {
                                            Text("Where the project stands today...")
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        
                        // Next Steps
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Next Steps")
                                .font(.headline)
                            TextEditor(text: $nextSteps)
                                .frame(minHeight: 80)
                                .overlay(
                                    Group {
                                        if nextSteps.isEmpty {
                                            Text("Immediate actionable items...")
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        
                        // Challenges
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Challenges & Solutions")
                                .font(.headline)
                            TextEditor(text: $challenges)
                                .frame(minHeight: 60)
                                .overlay(
                                    Group {
                                        if challenges.isEmpty {
                                            Text("Known challenges and potential solutions...")
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        
                        // User Experience
                        VStack(alignment: .leading, spacing: 8) {
                            Text("User/Audience Experience")
                                .font(.headline)
                            TextEditor(text: $userExperience)
                                .frame(minHeight: 60)
                                .overlay(
                                    Group {
                                        if userExperience.isEmpty {
                                            Text("How users will interact with or experience the project...")
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        
                        // Success Metrics
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Success Metrics")
                                .font(.headline)
                            TextEditor(text: $successMetrics)
                                .frame(minHeight: 60)
                                .overlay(
                                    Group {
                                        if successMetrics.isEmpty {
                                            Text("How will you measure success...")
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        
                        // Research
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Research & References")
                                .font(.headline)
                            TextEditor(text: $research)
                                .frame(minHeight: 60)
                                .overlay(
                                    Group {
                                        if research.isEmpty {
                                            Text("Supporting materials, inspiration, documentation...")
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        
                        // Open Questions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Open Questions & Considerations")
                                .font(.headline)
                            TextEditor(text: $openQuestions)
                                .frame(minHeight: 60)
                                .overlay(
                                    Group {
                                        if openQuestions.isEmpty {
                                            Text("Ongoing thoughts, future possibilities...")
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        
                        // External Files
                        VStack(alignment: .leading, spacing: 8) {
                            Text("External Files")
                                .font(.headline)
                            TextEditor(text: $externalFiles)
                                .frame(minHeight: 60)
                                .overlay(
                                    Group {
                                        if externalFiles.isEmpty {
                                            Text("Files related to the project outside of the Obsidian folder...")
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        
                        // Repositories
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Repositories")
                                .font(.headline)
                            TextEditor(text: $repositories)
                                .frame(minHeight: 80)
                                .overlay(
                                    Group {
                                        if repositories.isEmpty {
                                            Text("Local and GitHub repositories related to this project...")
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                    }
                    .padding()
                }
                .formStyle(.grouped)
            }
            .padding()
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Vibe Input") {
                    showingVoiceInput = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
                
                Spacer()
                
                Button("Create Project") {
                    createProject()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            }
            .padding()
        }
        .frame(width: 800, height: 800)
        .sheet(isPresented: $showingVoiceInput) {
            VibeInputSheet(
                inputMode: $inputMode,
                textInput: $textInput,
                isRecording: $isRecording,
                recordingDuration: $recordingDuration,
                audioLevel: $audioLevel,
                processingStatus: $processingStatus,
                isProcessing: $isProcessing,
                onStartRecording: startRecording,
                onStopRecording: stopRecording,
                onProcessText: processTextInput,
                onDismiss: { showingVoiceInput = false }
            )
        }
        .alert("Error Creating Project", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createProject() {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        var projectOverview = ProjectOverview()
        
        // Fill in all the fields with either user input or default placeholders
        projectOverview.coreConcept = coreConcept.isEmpty ? "[Comprehensive overview of what the project is and its primary purpose]" : coreConcept
        projectOverview.guidingPrinciples = guidingPrinciples.isEmpty ? "[The underlying philosophy, values, and goals driving the project]" : guidingPrinciples
        projectOverview.keyFeatures = keyFeatures.isEmpty ? "[Detailed list of all features/components with descriptions]" : keyFeatures
        projectOverview.architecture = architecture.isEmpty ? "[Technical architecture or organizational structure]" : architecture
        projectOverview.implementationRoadmap = implementationRoadmap.isEmpty ? "[Phase-by-phase implementation plan]" : implementationRoadmap
        projectOverview.currentStatus = currentStatus.isEmpty ? "[Summary of where the project stands]" : currentStatus
        projectOverview.nextSteps = nextSteps.isEmpty ? "[Immediate actionable items]" : nextSteps
        projectOverview.challenges = challenges.isEmpty ? "[Technical, creative, or logistical challenges with proposed solutions]" : challenges
        projectOverview.userExperience = userExperience.isEmpty ? "[How the end user will interact with or experience the project]" : userExperience
        projectOverview.successMetrics = successMetrics.isEmpty ? "[Project-specific criteria for measuring success]" : successMetrics
        projectOverview.research = research.isEmpty ? "[Supporting materials, inspiration sources, technical documentation]" : research
        projectOverview.openQuestions = openQuestions.isEmpty ? "[Ongoing thoughts, future possibilities, parking lot for ideas]" : openQuestions
        projectOverview.externalFiles = externalFiles.isEmpty ? "[Any files related to the project outside of the Obsidian folder and their locations]" : externalFiles
        projectOverview.repositories = repositories.isEmpty ? "[Local and GitHub repositories related to this project]" : repositories
        
        do {
            try projectsManager.createProject(name: trimmedName, overview: projectOverview)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    // MARK: - Voice Recording Methods
    
    private func startRecording() {
        guard !isRecording else { return }
        beginRecording()
    }
    
    private func beginRecording() {
        // Check microphone permission first
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("✅ Microphone permission: authorized")
        case .denied:
            print("❌ Microphone permission: denied")
            processingStatus = "Microphone access denied"
            return
        case .restricted:
            print("❌ Microphone permission: restricted")
            processingStatus = "Microphone access restricted"
            return
        case .notDetermined:
            print("⚠️ Microphone permission: not determined")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.beginRecording()
                    } else {
                        self.processingStatus = "Microphone permission denied"
                    }
                }
            }
            return
        @unknown default:
            print("❓ Microphone permission: unknown")
        }
        
        // Check available audio input devices
        let audioDevices = AVCaptureDevice.devices(for: .audio)
        print("Available audio input devices: \(audioDevices.count)")
        for (index, device) in audioDevices.enumerated() {
            print("  \(index): \(device.localizedName) - \(device.uniqueID)")
        }
        
        // AAC recording settings - record directly to m4a (reduced bitrate)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,  // Standard sample rate for macOS
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64000  // Reduced from 128k for better compatibility
        ]
        
        // Build a file URL ending in .m4a right away
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "voice_input_\(dateFormatter.string(from: Date())).m4a"
        recordingURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord() // Allocate buffers early
            
            let recordingStarted = audioRecorder?.record() ?? false
            print("Recording started successfully: \(recordingStarted)")
            print("Audio recorder settings: \(settings)")
            
            // Update state
            isRecording = true
            recordingStartTime = Date()
            processingStatus = "Recording..."
            
            // Start timers
            startTimers()
            
        } catch {
            print("Failed to start recording: \(error)")
            processingStatus = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        
        // Debug: Log current recording time before stopping
        if let recorder = audioRecorder {
            print("audioRecorder.currentTime before stop(): \(recorder.currentTime) seconds")
        }
        
        // Stop the audio recorder
        audioRecorder?.stop()
        
        // Debug: Log current recording time to check if encoder has flushed
        if let recorder = audioRecorder {
            print("audioRecorder.currentTime after stop(): \(recorder.currentTime) seconds")
            print("audioRecorder.isRecording after stop(): \(recorder.isRecording)")
        }
        
        // Cancel timers
        durationTimer?.invalidate()
        durationTimer = nil
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        
        // Update state
        isRecording = false
        audioLevel = 0
        processingStatus = "Processing audio..."
        isProcessing = true
        
        // Process the m4a file directly (no conversion needed)
        if let m4aURL = recordingURL {
            // Give the AAC encoder time to properly finalize the m4a container
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Check if the m4a file exists and has content
                if FileManager.default.fileExists(atPath: m4aURL.path) {
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: m4aURL.path)
                        let fileSize = attributes[.size] as? Int64 ?? 0
                        print("M4A file size: \(fileSize) bytes, duration recorded: \(self.recordingDuration) seconds")
                        
                        let minBytes: Int64 = 20 * 1024     // 20 KB ~= 1 s of AAC
                        if fileSize > minBytes {
                            print("✅ M4A file ready for transcription: \(m4aURL.path)")
                            self.processAudioRecording(url: m4aURL)
                        } else {
                            print("M4A file too small: \(fileSize) bytes (minimum: \(minBytes))")
                            self.processingStatus = "Recording too short or empty"
                            self.isProcessing = false
                        }
                    } catch {
                        print("Error checking M4A file: \(error)")
                        self.processingStatus = "Error checking audio file"
                        self.isProcessing = false
                    }
                } else {
                    print("M4A file does not exist: \(m4aURL.path)")
                    self.processingStatus = "Audio file not found"
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func startTimers() {
        // Duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let startTime = recordingStartTime {
                recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
        
        // Audio level timer
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            audioRecorder?.updateMeters()
            if let recorder = audioRecorder {
                let avgPower = recorder.averagePower(forChannel: 0)
                let peakPower = recorder.peakPower(forChannel: 0)
                let normalizedLevel = (avgPower + 80) / 80  // Normalize from -80dB to 0dB
                audioLevel = max(0.0, min(1.0, normalizedLevel))
                
                // Debug: Log audio levels periodically to see if we're getting input
                if Int(Date().timeIntervalSince1970) % 2 == 0 && Int(Date().timeIntervalSince1970 * 10) % 10 == 0 {
                    print("Audio levels - Avg: \(avgPower) dB, Peak: \(peakPower) dB, Normalized: \(normalizedLevel)")
                }
            }
        }
    }
    
    private func processAudioRecording(url: URL) {
        // Use the same transcription service as VoiceRecorderMac2
        transcriptionService = TranscriptionService()
        
        transcriptionService!.transcribeAudio(
            fileURL: url,
            requiresSecondAPICall: true,  // Re-enabled for full project overview generation
            promptForSecondCall: generateProjectOverviewPrompt(),
            statusUpdate: { status in
                DispatchQueue.main.async {
                    processingStatus = status
                }
            }
        ) { result in
            DispatchQueue.main.async {
                isProcessing = false
                
                switch result {
                case .success(let transcriptionResult):
                    parseAndPopulateFields(from: transcriptionResult.final)
                    showingVoiceInput = false
                    
                    // Clean up the m4a file
                    try? FileManager.default.removeItem(at: url)
                    
                case .failure(let error):
                    processingStatus = "Error: \(error.localizedDescription)"
                    print("Transcription error: \(error)")
                    // Clean up the m4a file on error too
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }
    
    private func processTextInput() {
        guard !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            processingStatus = "Please enter some text first"
            return
        }
        
        isProcessing = true
        processingStatus = "Processing text input..."
        
        // Use the same transcription service but skip the audio transcription step
        transcriptionService = TranscriptionService()
        
        // Use the private processTranscription method directly (we need to access it through the transcribeAudio method)
        // Since processTranscription is private, we'll simulate by calling transcribeAudio but with a dummy approach
        // Instead, let's use the approach of calling the service with requiresSecondAPICall = true and a pre-transcribed text
        
        // We'll create a temporary file with the text and then process it
        // Actually, let's use a better approach - create a processTextDirectly method in TranscriptionService
        // For now, let's use a simpler approach by accessing the private method through reflection or creating a public version
        
        // Simple approach: simulate the GPT call directly using URLSession
        processTextDirectlyWithGPT(
            text: textInput,
            prompt: generateProjectOverviewPrompt(),
            statusUpdate: { status in
                DispatchQueue.main.async {
                    processingStatus = status
                }
            }
        ) { result in
            DispatchQueue.main.async {
                isProcessing = false
                
                switch result {
                case .success(let processedText):
                    parseAndPopulateFields(from: processedText)
                    showingVoiceInput = false
                    textInput = "" // Clear the text input
                    
                case .failure(let error):
                    processingStatus = "Error: \(error.localizedDescription)"
                    print("Text processing error: \(error)")
                }
            }
        }
    }
    
    
    private func processTextDirectlyWithGPT(
        text: String,
        prompt: String,
        statusUpdate: ((String) -> Void)?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Get API key from secure storage
        guard let apiKey = SecureTokenStorage.shared.getOpenAIKey() else {
            statusUpdate?("Error: OpenAI API key not configured")
            completion(.failure(NSError(domain: "TranscriptionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured"])))
            return
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(NSError(domain: "TranscriptionError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid API endpoint"])))
            return
        }
        
        statusUpdate?("Sending text to GPT for processing...")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300 // 5 minutes timeout
        
        let messages = [
            ["role": "system", "content": prompt],
            ["role": "user", "content": text]
        ]
        
        let body: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 4000
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            statusUpdate?("Processing with GPT...")
        } catch {
            statusUpdate?("Error preparing request: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                statusUpdate?("GPT processing failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                statusUpdate?("Invalid response received")
                completion(.failure(NSError(domain: "TranscriptionError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response received"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                statusUpdate?("GPT API error (Status: \(httpResponse.statusCode))")
                if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                    completion(.failure(NSError(domain: "TranscriptionError", code: 4, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorMessage)"])))
                } else {
                    completion(.failure(NSError(domain: "TranscriptionError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Server Error: \(httpResponse.statusCode)"])))
                }
                return
            }
            
            guard let data = data else {
                statusUpdate?("No data received from GPT")
                completion(.failure(NSError(domain: "TranscriptionError", code: 6, userInfo: [NSLocalizedDescriptionKey: "No data received from server"])))
                return
            }
            
            do {
                statusUpdate?("Processing GPT response...")
                
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let processedText = message["content"] as? String {
                    
                    statusUpdate?("Processing complete!")
                    completion(.success(processedText))
                } else {
                    statusUpdate?("Failed to parse GPT response")
                    completion(.failure(NSError(domain: "TranscriptionError", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to parse server response"])))
                }
            } catch {
                statusUpdate?("Error decoding GPT response: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    private func generateProjectOverviewPrompt() -> String {
        return """
        You are an expert project manager helping to structure a project overview. Based on the voice recording transcription, create a comprehensive project overview document with the following sections. Return ONLY the structured content below with no additional text, summary, or commentary.

        ## Project Name
        [A clear, concise name for the project based on the transcription]

        ## Core Concept
        [Comprehensive overview of what the project is and its primary purpose]

        ## Guiding Principles & Intentions
        [The underlying philosophy, values, and goals driving the project]

        ## Key Features & Functionality
        [Detailed list of all features/components with descriptions]

        ## Architecture & Structure
        [Technical architecture or organizational structure]

        ## Implementation Roadmap
        [Phase-by-phase implementation plan]

        ## Current Status & Progress
        [Summary of where the project stands]

        ## Next Steps
        [Immediate actionable items]

        ## Challenges & Solutions
        [Technical, creative, or logistical challenges with proposed solutions]

        ## User/Audience Experience
        [How the end user will interact with or experience the project]

        ## Success Metrics
        [Project-specific criteria for measuring success]

        ## Research & References
        [Supporting materials, inspiration sources, technical documentation]

        ## Open Questions & Considerations
        [Ongoing thoughts, future possibilities, parking lot for ideas]

        ## External Files
        [Any files related to the project outside of the project folder and their locations]

        ## Repositories
        [Local and GitHub repositories related to this project]

        IMPORTANT: Respond with ONLY the structured content above. Do not add any introductory text, concluding remarks, summaries, or additional commentary. Fill in each section based on what was mentioned in the voice recording, using brief placeholders for sections not covered.
        """
    }
    
    private func parseAndPopulateFields(from content: String) {
        // First, try to extract the project name from a "Project Name" section
        if projectName.isEmpty {
            let extractedProjectName = extractProjectName(from: content)
            if !extractedProjectName.isEmpty {
                projectName = extractedProjectName
            }
        }
        
        let overview = MarkdownParser.parseProjectOverview(from: content)
        
        // Fallback: If project name is still empty, try to extract it from the first line of content that might contain the name
        if projectName.isEmpty {
            // Look for lines that might contain the project name (often after colons or in the beginning)
            let lines = content.components(separatedBy: "\n")
            for line in lines.prefix(10) {  // Only check first 10 lines
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                // Skip headers and empty lines
                if trimmedLine.hasPrefix("#") || trimmedLine.isEmpty || trimmedLine.hasPrefix("[") {
                    continue
                }
                // If line looks like it might contain a project name (reasonably short, not obviously description text)
                if trimmedLine.count > 5 && trimmedLine.count < 80 && !trimmedLine.lowercased().contains("project") {
                    projectName = trimmedLine
                    break
                }
            }
        }
        
        // Populate all fields, but don't overwrite existing content
        if coreConcept.isEmpty { coreConcept = overview.coreConcept }
        if guidingPrinciples.isEmpty { guidingPrinciples = overview.guidingPrinciples }
        if keyFeatures.isEmpty { keyFeatures = overview.keyFeatures }
        if architecture.isEmpty { architecture = overview.architecture }
        if implementationRoadmap.isEmpty { implementationRoadmap = overview.implementationRoadmap }
        if currentStatus.isEmpty { currentStatus = overview.currentStatus }
        if nextSteps.isEmpty { nextSteps = overview.nextSteps }
        if challenges.isEmpty { challenges = overview.challenges }
        if userExperience.isEmpty { userExperience = overview.userExperience }
        if successMetrics.isEmpty { successMetrics = overview.successMetrics }
        if research.isEmpty { research = overview.research }
        if openQuestions.isEmpty { openQuestions = overview.openQuestions }
        if externalFiles.isEmpty { externalFiles = overview.externalFiles }
        if repositories.isEmpty { repositories = overview.repositories }
    }
    
    private func extractProjectName(from content: String) -> String {
        let sections = content.components(separatedBy: "\n## ")
        
        for section in sections {
            let lines = section.split(separator: "\n", omittingEmptySubsequences: false)
            guard !lines.isEmpty else { continue }
            
            let headerLine = lines[0].trimmingCharacters(in: .whitespaces)
            
            // Handle both "## Project Name" (first section) and "Project Name" (subsequent sections)
            if headerLine == "Project Name" || headerLine == "## Project Name" {
                let contentLines = Array(lines.dropFirst())
                let content = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                // Clean up any placeholder brackets
                let cleaned = content.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
                return cleaned
            }
        }
        
        return ""
    }
}

// MARK: - Vibe Input Sheet

struct VibeInputSheet: View {
    @Binding var inputMode: NewProjectForm.InputMode
    @Binding var textInput: String
    @Binding var isRecording: Bool
    @Binding var recordingDuration: TimeInterval
    @Binding var audioLevel: Float
    @Binding var processingStatus: String
    @Binding var isProcessing: Bool
    
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onProcessText: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("Vibe Input")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Describe your project idea and it will be automatically structured into the project overview format.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Mode selector
                Picker("Input Mode", selection: $inputMode) {
                    ForEach(NewProjectForm.InputMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }
            
            VStack(spacing: 20) {
                if inputMode == .voice {
                    // Voice input mode - existing functionality
                    // Recording visualization
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red.opacity(0.2) : Color.gray.opacity(0.2))
                            .frame(width: 200, height: 200)
                        
                        Circle()
                            .fill(isRecording ? Color.red : Color.gray)
                            .frame(width: 80 + CGFloat(audioLevel * 60), height: 80 + CGFloat(audioLevel * 60))
                            .animation(.easeInOut(duration: 0.1), value: audioLevel)
                        
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    .onTapGesture {
                        if isRecording {
                            onStopRecording()
                        } else if !isProcessing {
                            onStartRecording()
                        }
                    }
                    .disabled(isProcessing)
                    
                    // Duration and status
                    VStack(spacing: 8) {
                        if isRecording {
                            Text(formatDuration(recordingDuration))
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Text(processingStatus)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Instructions
                    if !isRecording && !isProcessing {
                        VStack(spacing: 8) {
                            Text("Tap the microphone to start recording")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Text("Speak naturally about your project idea, goals, features, and implementation plans.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    } else if isRecording {
                        Text("Tap the stop button when finished")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Text input mode - new functionality
                    VStack(spacing: 16) {
                        Text("Enter your project description")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            TextEditor(text: $textInput)
                                .frame(minHeight: 200)
                                .overlay(
                                    Group {
                                        if textInput.isEmpty {
                                            Text("Paste or type your project description here. Include details about your project idea, goals, features, and implementation plans.")
                                                .foregroundColor(.secondary.opacity(0.8))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 250)
                        
                        // Process button
                        Button("Process Text") {
                            onProcessText()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                        
                        // Status
                        if isProcessing {
                            Text(processingStatus)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Close button
            HStack {
                Spacer()
                
                Button("Cancel") {
                    onDismiss()
                }
                .disabled(isProcessing)
            }
        }
        .padding(32)
        .frame(width: 500, height: 600)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

