//
//  PhotoModerationService.swift
//  Smart Sort
//

import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UIKit
import Vision

struct PhotoModerationResult: Equatable {
    var isBlurry = false
    var containsFace = false
    var blurScore: Double = 0
}

protocol PhotoModerating: AnyObject {
    func evaluate(_ image: UIImage) async -> PhotoModerationResult
}

final class PhotoModerationService: PhotoModerating {
    static let shared = PhotoModerationService()

    private let context = CIContext()
    private let blurThreshold = 0.055

    private init() {}

    func evaluate(_ image: UIImage) async -> PhotoModerationResult {
        await Task.detached(priority: .userInitiated) { [context, blurThreshold] in
            let blurScore = Self.blurScore(for: image, context: context) ?? 1
            let containsFace = Self.containsFace(in: image)
            return PhotoModerationResult(
                isBlurry: blurScore < blurThreshold,
                containsFace: containsFace,
                blurScore: blurScore
            )
        }.value
    }

    nonisolated private static func blurScore(for image: UIImage, context: CIContext) -> Double? {
        guard let ciImage = normalizedCIImage(from: image) else { return nil }

        let maxDimension = max(ciImage.extent.width, ciImage.extent.height)
        guard maxDimension > 0 else { return nil }

        let scale = min(1, 256 / maxDimension)
        let resized = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = resized
        colorControls.saturation = 0
        colorControls.contrast = 1.1

        guard let grayscale = colorControls.outputImage else { return nil }

        let edges = CIFilter.edges()
        edges.inputImage = grayscale
        edges.intensity = 8

        guard let edgeImage = edges.outputImage else { return nil }

        let average = CIFilter.areaAverage()
        average.inputImage = edgeImage
        average.extent = edgeImage.extent

        guard let outputImage = average.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let luminance = (Double(pixel[0]) + Double(pixel[1]) + Double(pixel[2])) / (3 * 255)
        return luminance
    }

    nonisolated private static func containsFace(in image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation)
        )

        do {
            try handler.perform([request])
            let observations = request.results ?? []
            return !observations.isEmpty
        } catch {
            return false
        }
    }

    nonisolated private static func normalizedCIImage(from image: UIImage) -> CIImage? {
        if let ciImage = image.ciImage {
            return ciImage.oriented(CGImagePropertyOrientation(image.imageOrientation))
        }

        guard let cgImage = image.cgImage else { return nil }
        return CIImage(cgImage: cgImage).oriented(CGImagePropertyOrientation(image.imageOrientation))
    }
}

private extension CGImagePropertyOrientation {
    nonisolated init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .down:
            self = .down
        case .left:
            self = .left
        case .right:
            self = .right
        case .upMirrored:
            self = .upMirrored
        case .downMirrored:
            self = .downMirrored
        case .leftMirrored:
            self = .leftMirrored
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
