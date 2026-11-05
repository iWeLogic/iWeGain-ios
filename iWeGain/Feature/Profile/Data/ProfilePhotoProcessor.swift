import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Turns any picture into the small square JPEG kept in a Firestore document.
nonisolated enum ProfilePhotoProcessor {
    private static let size = 256
    private static let quality = 0.8

    /// A center-cropped 256 px JPEG, or nil when [data] isn't a picture.
    static func jpeg(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        // Downscaled so its shorter side still covers the square, with the photo's orientation applied.
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? size
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? size
        let longest = Double(size) * Double(max(width, height)) / Double(max(1, min(width, height)))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(longest.rounded(.up)),
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let side = min(thumbnail.width, thumbnail.height)
        let crop = CGRect(x: (thumbnail.width - side) / 2, y: (thumbnail.height - side) / 2, width: side, height: side)
        guard let square = thumbnail.cropping(to: crop) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, square, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }

    /// The picture at [url], or nil when it can't be fetched (offline).
    static func jpeg(from url: URL) async -> Data? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return jpeg(from: data)
    }
}
