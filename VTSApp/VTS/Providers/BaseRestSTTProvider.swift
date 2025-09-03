import Foundation

/// Base class for STT providers that provides common networking functionality
/// with retry logic and configurable timeouts
public class BaseRestSTTProvider: RestSTTProvider {
    public var providerType: STTProviderType {
        fatalError("Must be implemented by subclass")
    }
    
    // Network configuration
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 1.0 // seconds
    
    // Timeout configuration based on audio size
    private func calculateTimeout(for audioDataSize: Int) -> TimeInterval {
        // Base timeout of 30 seconds
        let baseTimeout: TimeInterval = 30.0
        
        // Add extra time based on audio size
        // ~1MB of audio = ~1 minute of speech, add 15 seconds per MB
        let megabytes = Double(audioDataSize) / (1024 * 1024)
        let additionalTimeout = megabytes * 15.0
        
        // Cap maximum timeout at 120 seconds (2 minutes)
        return min(baseTimeout + additionalTimeout, 120.0)
    }
    
    // MARK: - STTProvider Protocol Requirements (to be implemented by subclasses)
    
    public func transcribe(
        stream: AsyncThrowingStream<Data, Error>,
        config: ProviderConfig
    ) async throws -> String {
        fatalError("Must be implemented by subclass")
    }
    
    public func validateConfig(_ config: ProviderConfig) throws {
        fatalError("Must be implemented by subclass")
    }
    
    // MARK: - Protected Methods for Subclasses
    
    /// Performs a network request with retry logic and configurable timeout
    internal func performNetworkRequest(
        request: URLRequest,
        audioDataSize: Int,
        providerName: String
    ) async throws -> (Data, URLResponse) {
        let timeout = calculateTimeout(for: audioDataSize)
        print("\(providerName): Calculated timeout: \(timeout)s for audio size: \(audioDataSize) bytes")
        
        // Configure URLSession with calculated timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: config)
        
        var lastError: Error?
        
        // Retry loop
        for attempt in 1...maxRetries {
            do {
                print("\(providerName): Attempt \(attempt)/\(maxRetries) - sending transcription request...")
                let (data, response) = try await session.data(for: request)
                
                print("\(providerName): Successfully received response on attempt \(attempt)")
                return (data, response)
                
            } catch {
                lastError = error
                let isRetryableError = isNetworkErrorRetryable(error)
                
                print("\(providerName): Attempt \(attempt) failed with error: \(error)")
                
                // Don't retry if it's not a network error or if this was the last attempt
                if !isRetryableError || attempt == maxRetries {
                    print("\(providerName): Error is not retryable or max attempts reached")
                    break
                }
                
                // Calculate delay with exponential backoff
                let delaySeconds = baseRetryDelay * pow(2.0, Double(attempt - 1))
                print("\(providerName): Retrying in \(delaySeconds)s...")
                
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
        }
        
        // If we get here, all retries failed
        if let lastError = lastError {
            throw STTError.networkError("Network request failed after \(maxRetries) attempts: \(lastError.localizedDescription)")
        } else {
            throw STTError.networkError("Network request failed after \(maxRetries) attempts")
        }
    }
    
    /// Determines if an error is retryable (network/timeout errors)
    private func isNetworkErrorRetryable(_ error: Error) -> Bool {
        // Check for NSURLError cases that are typically retryable
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,                    // Request timed out
                 .cannotConnectToHost,         // Cannot connect to host
                 .networkConnectionLost,       // Network connection lost
                 .cannotFindHost,             // Cannot find host
                 .dnsLookupFailed,            // DNS lookup failed
                 .notConnectedToInternet,     // Not connected to internet
                 .badServerResponse,          // Bad server response
                 .cannotLoadFromNetwork:      // Cannot load from network
                return true
            default:
                return false
            }
        }
        
        // Check for general network errors
        if let nsError = error as NSError? {
            // CFNetwork errors
            if nsError.domain == "kCFErrorDomainCFNetwork" {
                return true
            }
            // NSURLError domain (backup check)
            if nsError.domain == NSURLErrorDomain {
                return true
            }
        }
        
        return false
    }
    
    /// Common WAV data creation method for all providers
    internal func createWAVData(from pcmData: Data) -> Data {
        let sampleRate: UInt32 = 16000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = UInt32(pcmData.count)
        let fileSize = 36 + dataSize
        
        var wavData = Data()
        
        // RIFF header
        wavData.append("RIFF".data(using: .ascii)!)
        var fileSizeLE = fileSize.littleEndian
        wavData.append(Data(bytes: &fileSizeLE, count: 4))
        wavData.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!)
        let fmtSize: UInt32 = 16
        var fmtSizeLE = fmtSize.littleEndian
        wavData.append(Data(bytes: &fmtSizeLE, count: 4))
        let audioFormat: UInt16 = 1 // PCM
        var audioFormatLE = audioFormat.littleEndian
        wavData.append(Data(bytes: &audioFormatLE, count: 2))
        var channelsLE = channels.littleEndian
        wavData.append(Data(bytes: &channelsLE, count: 2))
        var sampleRateLE = sampleRate.littleEndian
        wavData.append(Data(bytes: &sampleRateLE, count: 4))
        var byteRateLE = byteRate.littleEndian
        wavData.append(Data(bytes: &byteRateLE, count: 4))
        var blockAlignLE = blockAlign.littleEndian
        wavData.append(Data(bytes: &blockAlignLE, count: 2))
        var bitsPerSampleLE = bitsPerSample.littleEndian
        wavData.append(Data(bytes: &bitsPerSampleLE, count: 2))
        
        // data chunk
        wavData.append("data".data(using: .ascii)!)
        var dataSizeLE = dataSize.littleEndian
        wavData.append(Data(bytes: &dataSizeLE, count: 4))
        wavData.append(pcmData)
        
        return wavData
    }
} 