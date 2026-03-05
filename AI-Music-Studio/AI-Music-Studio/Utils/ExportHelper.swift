import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum ExportHelper {
    typealias ExportError = MP3Exporter.ExportError
    
    /// 导出音频：macOS 用保存面板写入所选路径；iOS 先写入临时文件再通过 completion 返回 URL，由调用方弹出分享 sheet。
    static func exportAudio(
        sourceURL: URL,
        suggestedFileName: String,
        completion: @escaping (Result<URL, ExportError>) -> Void
    ) {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.title = "导出"
        savePanel.nameFieldStringValue = suggestedFileName
        savePanel.allowedContentTypes = [UTType.mp3]
        if savePanel.runModal() == .OK, let destinationURL = savePanel.url {
            MP3Exporter.exportToMP3Simple(sourceURL: sourceURL, destinationURL: destinationURL) { result in
                DispatchQueue.main.async { completion(result) }
            }
        }
        #else
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(suggestedFileName)
        MP3Exporter.exportToMP3Simple(sourceURL: sourceURL, destinationURL: tempURL) { result in
            DispatchQueue.main.async { completion(result) }
        }
        #endif
    }
}

#if os(iOS)
struct ShareableFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    var onDismiss: (() -> Void)?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        vc.completionWithItemsHandler = { _, _, _, _ in
            onDismiss?()
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
