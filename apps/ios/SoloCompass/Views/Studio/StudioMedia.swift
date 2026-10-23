import UIKit
import Vision
import CoreImage

/// Imports only explicitly selected photos. No location/EXIF data is retained.
enum StudioMedia {
    static func normalized(_ data: Data) throws -> Data {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let factor = min(1, 1400 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let output = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = output.jpegData(compressionQuality: 0.86) else { throw CocoaError(.fileWriteUnknown) }
        return jpeg
    }

    static func foreground(_ data: Data) throws -> Data {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(data: data)
        try handler.perform([request])
        guard let result = request.results?.first, !result.allInstances.isEmpty else {
            throw CocoaError(.featureUnsupported)
        }
        let buffer = try result.generateMaskedImage(ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: true)
        let input = CIImage(cvPixelBuffer: buffer)
        guard let cgImage = CIContext().createCGImage(input, from: input.extent),
              let png = UIImage(cgImage: cgImage).pngData() else { throw CocoaError(.fileReadCorruptFile) }
        return png
    }
}
