import Foundation
import Combine

/// Protocol for transcription services across platforms
public protocol TranscriptionProtocol {
    /// Transcription progress publisher
    var progress: CurrentValueSubject<Double, Never> { get }
    
    /// Transcription state publisher
    var state: CurrentValueSubject<TranscriptionState, Never> { get }
    
    /// Transcribe audio file
    func transcribe(audioURL: URL) async throws -> String
    
    /// Cancel ongoing transcription
    func cancelTranscription()
    
    /// Check if service is available
    var isAvailable: Bool { get }
}

public enum TranscriptionState {
    case idle
    case preparing
    case transcribing
    case completed
    case failed(Error)
    case cancelled
}