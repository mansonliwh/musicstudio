import Foundation
import AVFoundation
import CoreAudio

class MP3Exporter {
    
    enum ExportError: Error {
        case noAudioFile
        case conversionFailed
        case fileWriteFailed
        
        var localizedDescription: String {
            switch self {
            case .noAudioFile: return "无法找到音频文件"
            case .conversionFailed: return "转换失败"
            case .fileWriteFailed: return "文件写入失败"
            }
        }
    }
    
    struct ExportOptions {
        var bitrate: Int = 192
        var sampleRate: Int = 44100
        var channels: Int = 2
        var title: String?
        var artist: String?
        var album: String?
        
        static let `default` = ExportOptions()
    }
    
    static func exportToMP3(
        sourceURL: URL,
        destinationURL: URL,
        options: ExportOptions = .default,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, ExportError>) -> Void
    ) {
        let asset = AVAsset(url: sourceURL)
        
        func runExport(audioTrack: AVAssetTrack) {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let reader = try AVAssetReader(asset: asset)
                    let readerOutput = AVAssetReaderTrackOutput(
                        track: audioTrack,
                        outputSettings: nil
                    )
                    reader.add(readerOutput)
                    reader.startReading()
                    
                    var totalFrames: AVAudioFrameCount = 0
                    while reader.status == .reading {
                        if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                            let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
                            totalFrames += UInt32(frameCount)
                        }
                    }
                    reader.cancelReading()
                    
                    let reader2 = try AVAssetReader(asset: asset)
                    let readerOutput2 = AVAssetReaderTrackOutput(
                        track: audioTrack,
                        outputSettings: [
                            AVFormatIDKey: kAudioFormatLinearPCM,
                            AVSampleRateKey: options.sampleRate,
                            AVNumberOfChannelsKey: options.channels,
                            AVLinearPCMBitDepthKey: 16,
                            AVLinearPCMIsFloatKey: false,
                            AVLinearPCMIsBigEndianKey: false
                        ]
                    )
                    reader2.add(readerOutput2)
                    reader2.startReading()
                    
                    let outputFile = try AVAudioFile(
                        forWriting: destinationURL,
                        settings: [
                            AVFormatIDKey: kAudioFormatMPEGLayer3,
                            AVSampleRateKey: options.sampleRate,
                            AVNumberOfChannelsKey: options.channels,
                            AVEncoderBitRateKey: options.bitrate * 1000
                        ]
                    )
                    
                    var framesProcessed: AVAudioFrameCount = 0
                    let bufferSize: AVAudioFrameCount = 8192
                    
                    while reader2.status == .reading {
                        guard AVAudioPCMBuffer(pcmFormat: outputFile.processingFormat, frameCapacity: bufferSize) != nil,
                              let sampleBuffer = readerOutput2.copyNextSampleBuffer() else {
                            break
                        }
                        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
                        framesProcessed += UInt32(frameCount)
                        DispatchQueue.main.async {
                            let progressValue = totalFrames > 0 ? Double(framesProcessed) / Double(totalFrames) : 0
                            progress(progressValue)
                        }
                    }
                    
                    if #available(macOS 15.0, iOS 18.0, *) {
                        outputFile.close()
                    }
                    reader2.cancelReading()
                    
                    DispatchQueue.main.async {
                        completion(.success(destinationURL))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(.conversionFailed))
                    }
                }
            }
        }
        
        if #available(macOS 13.0, iOS 15.0, *) {
            asset.loadTracks(withMediaType: .audio) { tracks, _ in
                guard let audioTrack = tracks?.first else {
                    completion(.failure(.noAudioFile))
                    return
                }
                runExport(audioTrack: audioTrack)
            }
        } else {
            guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
                completion(.failure(.noAudioFile))
                return
            }
            runExport(audioTrack: audioTrack)
        }
    }
    
    static func exportToMP3Simple(
        sourceURL: URL,
        destinationURL: URL,
        completion: @escaping (Result<URL, ExportError>) -> Void
    ) {
        let asset = AVAsset(url: sourceURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            completion(.failure(.conversionFailed))
            return
        }
        
        exportSession.outputURL = destinationURL.deletingPathExtension().appendingPathExtension("m4a")
        exportSession.outputFileType = .m4a
        
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    completion(.success(exportSession.outputURL!))
                case .failed, .cancelled:
                    completion(.failure(.conversionFailed))
                default:
                    break
                }
            }
        }
    }
    
    static func exportToWAV(
        sourceURL: URL,
        destinationURL: URL,
        completion: @escaping (Result<URL, ExportError>) -> Void
    ) {
        let asset = AVAsset(url: sourceURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            completion(.failure(.conversionFailed))
            return
        }
        
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .wav
        
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    completion(.success(destinationURL))
                case .failed, .cancelled:
                    completion(.failure(.conversionFailed))
                default:
                    break
                }
            }
        }
    }
}
