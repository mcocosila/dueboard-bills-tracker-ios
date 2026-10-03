// Draws the app icon: a white D on blue, with a gold coin seen in perspective at the
// bottom right, overlapping the D's curve, an embossed $ on its face.
//
// Run from the repo root:  swift scripts/draw-app-icon.swift
// It writes Dueboard/Assets.xcassets/AppIcon.appiconset/AppIcon.png: 1024x1024 with no
// alpha channel, as App Store Connect requires. A path as the first argument writes there
// instead, to try a change without touching the icon.
import AppKit

let output = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Dueboard/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

let size = 1024
let side = CGFloat(size)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

/// Draws text centred on `centre` by its glyph bounds, not its line box.
func drawCentred(_ text: String, font: NSFont, colour: NSColor, centre: CGPoint) {
    let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: colour])
    let line = CTLineCreateWithAttributedString(string)
    ctx.textPosition = .zero
    let glyph = CTLineGetImageBounds(line, ctx)
    ctx.textPosition = CGPoint(x: centre.x - glyph.midX, y: centre.y - glyph.midY)
    CTLineDraw(line, ctx)
}

// Background
ctx.setFillColor(rgb(0.0, 0.42, 0.85))
ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))

// The D, centred
drawCentred("D", font: .systemFont(ofSize: 640, weight: .bold), colour: .white,
            centre: CGPoint(x: side / 2, y: side / 2))

// The coin: a tilted ellipse over the D's lower-right curve, with its edge showing below the face
let coinCentre = CGPoint(x: 712, y: 300), tiltDegrees: CGFloat = 18
let rx: CGFloat = 160, ry: CGFloat = 108, thickness: CGFloat = 34
ctx.saveGState()
ctx.translateBy(x: coinCentre.x, y: coinCentre.y)
ctx.rotate(by: tiltDegrees * .pi / 180)
let face = CGRect(x: -rx, y: -ry, width: 2 * rx, height: 2 * ry)

// Soft shadow on the blue
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: -10, height: -22), blur: 36, color: rgb(0, 0.12, 0.3, 0.55))
ctx.setFillColor(rgb(0.62, 0.42, 0.05))
ctx.fillEllipse(in: face.offsetBy(dx: 0, dy: -thickness))
ctx.restoreGState()

// Edge: stacked ellipses make the thickness, crossed by milling lines
for i in stride(from: thickness, through: 0, by: -1) {
    let t = i / thickness
    ctx.setFillColor(rgb(0.70 - 0.12 * t, 0.48 - 0.10 * t, 0.06))
    ctx.fillEllipse(in: face.offsetBy(dx: 0, dy: -i))
}
ctx.saveGState()
ctx.addEllipse(in: face.offsetBy(dx: 0, dy: -thickness))
ctx.addRect(CGRect(x: -rx, y: -thickness, width: 2 * rx, height: thickness))
ctx.clip()
ctx.setStrokeColor(rgb(0.45, 0.30, 0.03, 0.55))
ctx.setLineWidth(3)
for x in stride(from: -rx + 8, to: rx, by: 14) {
    let top = -ry * sqrt(max(0, 1 - (x * x) / (rx * rx)))
    ctx.move(to: CGPoint(x: x, y: top))
    ctx.addLine(to: CGPoint(x: x, y: top - thickness))
}
ctx.strokePath()
ctx.restoreGState()

// Face: gold, lit from the top left
ctx.saveGState()
ctx.addEllipse(in: face)
ctx.clip()
let gold = CGGradient(colorsSpace: space,
                      colors: [rgb(1.0, 0.93, 0.55), rgb(0.98, 0.78, 0.22), rgb(0.85, 0.60, 0.10)] as CFArray,
                      locations: [0, 0.55, 1])!
ctx.drawRadialGradient(gold, startCenter: CGPoint(x: -rx * 0.35, y: ry * 0.45), startRadius: 0,
                       endCenter: .zero, endRadius: rx * 1.15, options: [.drawsAfterEndLocation])
ctx.restoreGState()

// Embossed $, foreshortened with the face: a light edge, a dark edge, then the sign
ctx.saveGState()
ctx.scaleBy(x: 1, y: ry / rx)
let dollar = NSFont.systemFont(ofSize: 200, weight: .heavy)
drawCentred("$", font: dollar, colour: NSColor(srgbRed: 1.0, green: 0.95, blue: 0.72, alpha: 0.95),
            centre: CGPoint(x: -4, y: 5))
drawCentred("$", font: dollar, colour: NSColor(srgbRed: 0.55, green: 0.35, blue: 0.02, alpha: 1),
            centre: CGPoint(x: 4, y: -5))
drawCentred("$", font: dollar, colour: NSColor(srgbRed: 0.84, green: 0.58, blue: 0.08, alpha: 1),
            centre: .zero)
ctx.restoreGState()

// Raised rim and a sheen
ctx.setStrokeColor(rgb(0.80, 0.56, 0.08))
ctx.setLineWidth(9)
ctx.strokeEllipse(in: face.insetBy(dx: 26, dy: 18))
ctx.setStrokeColor(rgb(1.0, 0.95, 0.70, 0.9))
ctx.setLineWidth(4)
ctx.strokeEllipse(in: face.insetBy(dx: 21, dy: 14).offsetBy(dx: -2, dy: 3))
ctx.saveGState()
ctx.addEllipse(in: face.insetBy(dx: 32, dy: 23))
ctx.clip()
ctx.setFillColor(rgb(1, 1, 1, 0.22))
ctx.fillEllipse(in: CGRect(x: -rx * 0.75, y: ry * 0.05, width: rx * 0.9, height: ry * 0.75))
ctx.restoreGState()
ctx.restoreGState()

let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
