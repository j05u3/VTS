import Foundation
import Combine

@MainActor
public class PartialResultsManager: ObservableObject {
    @Published public var currentPartialText: String = ""
    @Published public var finalizedSegments: [String] = []
    @Published public var isReceivingPartials: Bool = false
    
    private var lastFinalizedIndex = 0
    private var partialBuffer: String = ""
    private var segmentBuffer: [String] = []
    
    public init() {}
    
    /// Processes a partial transcription result chunk
    public func processPartialResult(_ chunk: TranscriptionChunk) {
        isReceivingPartials = true
        
        if chunk.isFinal {
            finalizeSegment(chunk.text)
        } else {
            updatePartialSegment(chunk.text)
        }
    }
    
    /// Updates the current partial segment being transcribed
    private func updatePartialSegment(_ text: String) {
        // Store the raw partial text
        partialBuffer = text
        
        // Only show complete words to avoid jarring mid-word cutoffs
        let processedText = processPartialText(text)
        currentPartialText = processedText
        
        print("PartialResultsManager: Updated partial text: '\(processedText)'")
    }
    
    /// Finalizes a completed segment and adds it to the finalized segments
    private func finalizeSegment(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespaces)
        
        if !trimmedText.isEmpty {
            segmentBuffer.append(trimmedText)
            finalizedSegments = segmentBuffer
            print("PartialResultsManager: Finalized segment: '\(trimmedText)'")
        }
        
        // Clear partial display
        currentPartialText = ""
        partialBuffer = ""
    }
    
    /// Processes partial text to show only complete words
    private func processPartialText(_ text: String) -> String {
        // Split into words
        let words = text.split(separator: " ")
        
        // If we have no words, return empty
        guard !words.isEmpty else { return "" }
        
        // If we have only one word and the original text doesn't end with space,
        // consider it incomplete and don't show it
        if words.count == 1 && !text.hasSuffix(" ") {
            return ""
        }
        
        // Show all words except the last one (which might be incomplete)
        // unless the text ends with a space (indicating the last word is complete)
        let completeWords: [String.SubSequence]
        if text.hasSuffix(" ") {
            completeWords = Array(words)
        } else {
            completeWords = Array(words.dropLast())
        }
        
        return completeWords.joined(separator: " ")
    }
    
    /// Returns the complete transcription combining finalized segments and current partial
    public func getCompleteTranscription() -> String {
        let finalizedText = finalizedSegments.joined(separator: " ")
        let partialText = currentPartialText
        
        if finalizedText.isEmpty {
            return partialText
        } else if partialText.isEmpty {
            return finalizedText
        } else {
            return "\(finalizedText) \(partialText)"
        }
    }
    
    /// Gets the final transcription text (finalized segments only)
    public func getFinalTranscription() -> String {
        return finalizedSegments.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
    
    /// Resets the partial results manager for a new session
    public func reset() {
        currentPartialText = ""
        finalizedSegments = []
        isReceivingPartials = false
        lastFinalizedIndex = 0
        partialBuffer = ""
        segmentBuffer = []
        
        print("PartialResultsManager: Reset for new session")
    }
    
    /// Returns debug information about the current state
    public func getDebugInfo() -> String {
        return """
        PartialResultsManager Debug Info:
        - Finalized segments: \(finalizedSegments.count)
        - Current partial: "\(currentPartialText)"
        - Is receiving partials: \(isReceivingPartials)
        - Partial buffer: "\(partialBuffer)"
        - Complete transcription: "\(getCompleteTranscription())"
        """
    }
}