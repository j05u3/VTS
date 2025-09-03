import Foundation
import Combine

class PartialResultsManager: ObservableObject {
    @Published var currentPartialText: String = ""
    @Published var finalizedSegments: [String] = []
    
    func processPartialResult(_ chunk: TranscriptionChunk) {
        // Handle incremental updates for status bar popup display only
        // No injection into active applications until final result
    }
}
