import Cocoa

// Regenerate the icons after changing icon-source.jpg:
//   swiftc -O mkicon.swift -o /tmp/mkicon
//   /tmp/mkicon icon-source.jpg icon.png            # 36px menu bar template
//   /tmp/mkicon icon-source.jpg /tmp/big.png 1024   # app icon master
//
// One-off: JPEG (black art on opaque white) -> template PNG.
// Template images use ONLY alpha, so set alpha = darkness and drop the white bg.
// Also trims the white margin so the glyph fills the icon box.

let src = CommandLine.arguments[1]
let dst = CommandLine.arguments[2]
// 36px bitmap shown at 18pt => crisp on retina; override for the app icon.
let outPx = CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3])! : 36

guard let img = NSImage(contentsOfFile: src),
      let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff) else { fatalError("cannot read \(src)") }

let w = rep.pixelsWide, h = rep.pixelsHigh

// alpha = 1 - luminance
var alpha = [[Double]](repeating: [Double](repeating: 0, count: w), count: h)
for y in 0..<h {
    for x in 0..<w {
        guard let c = rep.colorAt(x: x, y: y) else { continue }
        let lum = 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
        alpha[y][x] = 1.0 - lum
    }
}

// Trim to bounding box of visible ink.
var minX = w, maxX = -1, minY = h, maxY = -1
for y in 0..<h {
    for x in 0..<w where alpha[y][x] > 0.5 {
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }
}
guard maxX >= minX, maxY >= minY else { fatalError("no ink found") }
let bw = maxX - minX + 1, bh = maxY - minY + 1
let side = max(bw, bh)                     // square box, keeps aspect
let offX = (side - bw) / 2, offY = (side - bh) / 2

guard let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: outPx, pixelsHigh: outPx,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: outPx * 4, bitsPerPixel: 32) else { fatalError() }

// Box-filter downsample of the cropped square into the output.
for oy in 0..<outPx {
    for ox in 0..<outPx {
        let sx0 = Double(ox) / Double(outPx) * Double(side) - Double(offX)
        let sx1 = Double(ox + 1) / Double(outPx) * Double(side) - Double(offX)
        let sy0 = Double(oy) / Double(outPx) * Double(side) - Double(offY)
        let sy1 = Double(oy + 1) / Double(outPx) * Double(side) - Double(offY)
        var sum = 0.0, n = 0.0
        var sy = Int(sy0.rounded(.down))
        while Double(sy) < sy1 {
            var sx = Int(sx0.rounded(.down))
            while Double(sx) < sx1 {
                let gx = minX + sx, gy = minY + sy
                if sx >= 0, sy >= 0, gx >= 0, gx < w, gy >= 0, gy < h { sum += alpha[gy][gx] }
                n += 1; sx += 1
            }
            sy += 1
        }
        let a = n > 0 ? sum / n : 0
        // Black ink; alpha carries the shape (template images ignore RGB).
        out.setColor(NSColor(deviceRed: 0, green: 0, blue: 0, alpha: CGFloat(a)), atX: ox, y: oy)
    }
}

guard let png = out.representation(using: .png, properties: [:]) else { fatalError() }
try png.write(to: URL(fileURLWithPath: dst))
print("wrote \(dst) (\(outPx)x\(outPx), trimmed from \(bw)x\(bh) of \(w)x\(h))")
