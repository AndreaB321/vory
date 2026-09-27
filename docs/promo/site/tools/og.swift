// Renders the Open Graph share image (1200×630) with SF Pro: light tile, the icon, the tagline.
import AppKit
let W = 1200.0, H = 630.0
let img = NSImage(size: NSSize(width: W, height: H))
img.lockFocus()
NSColor(srgbRed: 0.949, green: 0.949, blue: 0.969, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: W, height: H).fill()
let glow = NSGradient(colors: [NSColor(srgbRed: 0.24, green: 0.77, blue: 0.93, alpha: 0.35), NSColor(srgbRed: 0.949, green: 0.949, blue: 0.969, alpha: 0)])!
glow.draw(in: NSRect(x: 0, y: 0, width: W, height: H), relativeCenterPosition: NSPoint(x: -0.6, y: 0.1))
let icon = NSImage(contentsOfFile: CommandLine.arguments[1])!
icon.draw(in: NSRect(x: 88, y: 105, width: 420, height: 420), from: .zero, operation: .sourceOver, fraction: 1)
func text(_ s: String, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor, x: CGFloat, y: CGFloat, rounded: Bool = false) {
    var font = NSFont.systemFont(ofSize: size, weight: weight)
    if rounded, let d = font.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: size) { font = f }
    let p = NSMutableParagraphStyle(); p.lineSpacing = -6
    let a: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .kern: size > 40 ? -1.5 : 0, .paragraphStyle: p]
    NSAttributedString(string: s, attributes: a).draw(at: NSPoint(x: x, y: y))
}
text("Vory · Public beta", 26, .semibold, NSColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 1), x: 556, y: 440)
text("Your agents,", 84, .heavy, NSColor(srgbRed: 0.04, green: 0.04, blue: 0.05, alpha: 1), x: 550, y: 330, rounded: true)
text("in your pocket.", 84, .heavy, NSColor(srgbRed: 0.04, green: 0.04, blue: 0.05, alpha: 1), x: 550, y: 240, rounded: true)
text("The iPhone remote for your", 30, .regular, NSColor(srgbRed: 0.43, green: 0.43, blue: 0.45, alpha: 1), x: 556, y: 170)
text("Hermes agent gateway.", 30, .regular, NSColor(srgbRed: 0.43, green: 0.43, blue: 0.45, alpha: 1), x: 556, y: 132)
text("vory.dev", 26, .semibold, NSColor(srgbRed: 0.43, green: 0.43, blue: 0.45, alpha: 1), x: 556, y: 72)
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
rep.size = NSSize(width: W, height: H)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("wrote", CommandLine.arguments[2], rep.pixelsWide, rep.pixelsHigh)
