import CoreImage
import CoreMedia
import ImageIO
import ReplayKit
import Vision

struct OCRResult {
    var transcript: String
    var languages: [String]
}

final class ScreenReader {
    // Used only on the handler's serial queue. One downscaled frame at a time.
    private let context = CIContext(options: [.cacheIntermediates: false])

    func read(_ sample: CMSampleBuffer, settings: Settings) throws -> OCRResult {
        guard let buffer = CMSampleBufferGetImageBuffer(sample) else {
            return OCRResult(transcript: "", languages: [])
        }
        let raw = (CMGetAttachment(sample, key: RPVideoSampleOrientationKey as CFString,
                                   attachmentModeOut: nil) as? NSNumber)?.uint32Value ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: raw) ?? .up
        let image = CIImage(cvPixelBuffer: buffer).oriented(orientation)
        // Initial prototype is portrait-only. Never guess a landscape crop.
        guard image.extent.height > image.extent.width else {
            throw NSError(domain: "ChatPilot", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "第一版仅支持竖屏，请转回竖屏。"])
        }
        let bounds = image.extent
        let crop = CGRect(x: bounds.minX,
                          y: bounds.minY + bounds.height * (1 - settings.cropBottom),
                          width: bounds.width,
                          height: bounds.height * (settings.cropBottom - settings.cropTop))
        let clipped = image.cropped(to: crop)
        let scale = min(1, 1100 / max(crop.width, crop.height))
        let scaled = clipped.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            throw PilotError.response
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let supported = try request.supportedRecognitionLanguages()
        let desired = ["vi-VN", "zh-Hans", "en-US"]
        request.recognitionLanguages = desired.filter { supported.contains($0) }
        request.automaticallyDetectsLanguage = true
        try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        let lines = (request.results ?? []).sorted {
            if abs($0.boundingBox.midY - $1.boundingBox.midY) < 0.012 {
                return $0.boundingBox.minX < $1.boundingBox.minX
            }
            return $0.boundingBox.midY > $1.boundingBox.midY
        }.compactMap { observation -> String? in
            guard let candidate = observation.topCandidates(1).first, candidate.confidence >= 0.35 else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let side = observation.boundingBox.midX < 0.5 ? "LEFT" : "RIGHT"
            return "[\(side)] \(text)"
        }
        return OCRResult(transcript: String(lines.suffix(45).joined(separator: "\n").suffix(6000)),
                         languages: request.recognitionLanguages)
    }
}
