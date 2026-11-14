// Renders the app icon "Growing plates" (Figma: Components > Final app icon, the same shapes as Android's
// ic_launcher_foreground.xml) into the iPhone, Mac and Apple Watch AppIcon sets.
//
//     swift ios/scripts/render_app_icon.swift
//
// The shapes are on Android's 512 grid, drawn full size on the 1024 icon. Light: the Android icon on white.
// Dark: the dark accent blended toward the dark background at the same steps, on a transparent background (iOS
// draws its own). Tinted: grayscale alpha steps (Android's monochrome layer). Mac icons aren't masked by the
// system, so they're a rounded tile with Apple's margin.
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct RGB { let r, g, b: CGFloat }

func hex(_ value: UInt32) -> RGB {
    RGB(r: CGFloat((value >> 16) & 0xFF) / 255, g: CGFloat((value >> 8) & 0xFF) / 255, b: CGFloat(value & 0xFF) / 255)
}

func mix(_ a: RGB, _ b: RGB, _ t: CGFloat) -> RGB {
    RGB(r: a.r * t + b.r * (1 - t), g: a.g * t + b.g * (1 - t), b: a.b * t + b.b * (1 - t))
}

/// A pill on the 512 grid: x, y, width, height, corner radius.
struct Shape { let rect: CGRect; let radius: CGFloat }

let bar = Shape(rect: CGRect(x: 80, y: 238, width: 352, height: 36), radius: 18)
let plates = [
    Shape(rect: CGRect(x: 130, y: 176, width: 60, height: 160), radius: 20),
    Shape(rect: CGRect(x: 226, y: 136, width: 60, height: 240), radius: 20),
    Shape(rect: CGRect(x: 322, y: 96, width: 60, height: 320), radius: 20),
]
/// How much accent each plate has (the rest is background), small to big; the bar is see-through.
let plateSteps: [CGFloat] = [0.45, 0.72, 1.0]

struct Style {
    let background: RGB?
    let accent: RGB
    /// What the plates blend toward.
    let base: RGB
    let barAlpha: CGFloat
    /// Grayscale: plates are white at the step's alpha instead of a blended color.
    var alphaSteps = false
}

let lightAccent = hex(0x5A8A00)
let light = Style(background: hex(0xFFFFFF), accent: lightAccent, base: hex(0xFFFFFF), barAlpha: 0.2)
let dark = Style(background: nil, accent: hex(0xC6FF3D), base: hex(0x0B0B0F), barAlpha: 0.3)
let tinted = Style(background: nil, accent: hex(0xFFFFFF), base: hex(0x000000), barAlpha: 0.3, alphaSteps: true)

func color(_ c: RGB, alpha: CGFloat = 1) -> CGColor { CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: alpha) }

/// Draws the icon on a `size` canvas. With `macTile`, a rounded tile with Apple's macOS margin (824 of 1024).
func render(_ style: Style, size: Int, macTile: Bool = false) -> CGImage {
    let s = CGFloat(size)
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    // Top-left origin like the Android path data.
    context.translateBy(x: 0, y: s)
    context.scaleBy(x: 1, y: -1)
    var canvas = CGRect(x: 0, y: 0, width: s, height: s)
    if macTile {
        let inset = s * 100 / 1024
        canvas = canvas.insetBy(dx: inset, dy: inset)
        let tile = CGPath(roundedRect: canvas, cornerWidth: canvas.width * 0.225, cornerHeight: canvas.width * 0.225, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -s * 10 / 1024), blur: s * 20 / 1024, color: CGColor(gray: 0, alpha: 0.3))
        context.addPath(tile)
        context.setFillColor(color(style.background ?? hex(0xFFFFFF)))
        context.fillPath()
        context.restoreGState()
    } else if let background = style.background {
        context.setFillColor(color(background))
        context.fill(canvas)
    }
    let scale = canvas.width / 512
    func fill(_ shape: Shape, _ fill: CGColor) {
        let r = CGRect(
            x: canvas.minX + shape.rect.minX * scale, y: canvas.minY + shape.rect.minY * scale,
            width: shape.rect.width * scale, height: shape.rect.height * scale
        )
        context.addPath(CGPath(roundedRect: r, cornerWidth: shape.radius * scale, cornerHeight: shape.radius * scale, transform: nil))
        context.setFillColor(fill)
        context.fillPath()
    }
    fill(bar, color(style.accent, alpha: style.barAlpha))
    for (plate, step) in zip(plates, plateSteps) {
        fill(plate, style.alphaSteps ? color(style.accent, alpha: step) : color(mix(style.accent, style.base, step)))
    }
    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Couldn't write \(url.path)") }
}

/// An opaque copy (no alpha channel): App Store icons must not have one.
func opaque(_ image: CGImage) -> CGImage {
    let context = CGContext(
        data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return context.makeImage()!
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let phoneSet = root.appendingPathComponent("iWeGain/Resources/Assets.xcassets/AppIcon.appiconset")
let watchSet = root.appendingPathComponent("iWeGainWatch/Resources/Assets.xcassets/AppIcon.appiconset")

var images: [[String: Any]] = []
write(opaque(render(light, size: 1024)), to: phoneSet.appendingPathComponent("AppIcon.png"))
images.append(["filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"])
write(render(dark, size: 1024), to: phoneSet.appendingPathComponent("AppIcon-Dark.png"))
images.append(["appearances": [["appearance": "luminosity", "value": "dark"]], "filename": "AppIcon-Dark.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"])
write(render(tinted, size: 1024), to: phoneSet.appendingPathComponent("AppIcon-Tinted.png"))
images.append(["appearances": [["appearance": "luminosity", "value": "tinted"]], "filename": "AppIcon-Tinted.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"])
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "AppIcon-Mac-\(points)@\(scale)x.png"
        write(render(light, size: points * scale, macTile: true), to: phoneSet.appendingPathComponent(name))
        images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
    }
}

func writeContents(_ images: [[String: Any]], to set: URL) {
    let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
    let data = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try! data.write(to: set.appendingPathComponent("Contents.json"))
}
writeContents(images, to: phoneSet)

// watchOS masks it to a circle; the glyph already fits inside it.
write(opaque(render(light, size: 1024)), to: watchSet.appendingPathComponent("AppIcon.png"))
writeContents([["filename": "AppIcon.png", "idiom": "universal", "platform": "watchos", "size": "1024x1024"]], to: watchSet)
print("Wrote \(phoneSet.path) and \(watchSet.path)")
