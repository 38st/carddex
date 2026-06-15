import SwiftUI
import ImageIO
import UIKit

/// Decoded-image cache with decode-time downsampling. Replaces bare `AsyncImage`,
/// which has no memory cache and re-decodes full-resolution images on every cell
/// reuse — janky and memory-heavy in a big grid. NSCache is thread-safe.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    func image(for url: URL, maxPixel: CGFloat) async -> UIImage? {
        let key = "\(url.absoluteString)|\(Int(maxPixel))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        guard let image = Self.downsample(data: data, maxPixel: maxPixel) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    private static func downsample(data: Data, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// Loads a remote image through `ImageCache` (cached + downsampled), showing a
/// placeholder while loading or on failure.
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    var maxPixel: CGFloat = 700
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            uiImage = nil
            guard let url else { return }
            let loaded = await ImageCache.shared.image(for: url, maxPixel: maxPixel)
            withAnimation(.easeOut(duration: 0.25)) { uiImage = loaded }
        }
    }
}
