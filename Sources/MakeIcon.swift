// makeicon.swift —— 用 CoreGraphics 绘制 MailSink 的 App 图标（1024x1024，带透明圆角）
import AppKit

let S: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
ctx.clear(CGRect(x: 0, y: 0, width: S, height: S))

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a).cgColor
}

// ---- 底板：macOS 圆角方形 ----
let inset: CGFloat = 100
let plate = CGRect(x: inset, y: inset, width: S - inset*2, height: S - inset*2)
let radius = plate.width * 0.2255
let platePath = CGPath(roundedRect: plate, cornerWidth: radius, cornerHeight: radius, transform: nil)

// 投影（让图标在浅色背景上立得住）
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 34,
              color: rgb(20, 22, 60, 0.34))
ctx.addPath(platePath)
ctx.setFillColor(rgb(70, 78, 240))
ctx.fillPath()
ctx.restoreGState()

// 渐变底
ctx.saveGState()
ctx.addPath(platePath)
ctx.clip()
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [rgb(59, 84, 245), rgb(126, 62, 226), rgb(160, 58, 196)] as CFArray,
                      locations: [0, 0.55, 1])!
ctx.drawLinearGradient(grad,
                       start: CGPoint(x: plate.minX + 40, y: plate.maxY - 20),
                       end: CGPoint(x: plate.maxX - 20, y: plate.minY + 30),
                       options: [])

// 顶部柔光
let sheen = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: [rgb(255, 255, 255, 0.22), rgb(255, 255, 255, 0)] as CFArray,
                       locations: [0, 1])!
ctx.drawLinearGradient(sheen,
                       start: CGPoint(x: plate.midX, y: plate.maxY),
                       end: CGPoint(x: plate.midX, y: plate.midY - 40),
                       options: [])
ctx.restoreGState()

// 内描边，模拟边缘高光
ctx.saveGState()
ctx.addPath(platePath)
ctx.clip()
ctx.addPath(platePath)
ctx.setStrokeColor(rgb(255, 255, 255, 0.20))
ctx.setLineWidth(6)
ctx.strokePath()
ctx.restoreGState()

// ---- 信封 ----
let envW: CGFloat = 476, envH: CGFloat = 342
let envCenter = CGPoint(x: 496, y: 556)
ctx.saveGState()
ctx.translateBy(x: envCenter.x, y: envCenter.y)
ctx.rotate(by: -6 * .pi / 180)

let envRect = CGRect(x: -envW/2, y: -envH/2, width: envW, height: envH)
let envPath = CGPath(roundedRect: envRect, cornerWidth: 40, cornerHeight: 40, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: rgb(15, 15, 60, 0.32))
ctx.addPath(envPath)
ctx.setFillColor(rgb(255, 255, 255))
ctx.fillPath()
ctx.restoreGState()

// 信封口（V 形折线）
ctx.saveGState()
ctx.addPath(envPath)
ctx.clip()
let flap = CGMutablePath()
flap.move(to: CGPoint(x: envRect.minX + 26, y: envRect.maxY - 22))
flap.addLine(to: CGPoint(x: 0, y: envRect.minY + 92))
flap.addLine(to: CGPoint(x: envRect.maxX - 26, y: envRect.maxY - 22))
ctx.addPath(flap)
ctx.setStrokeColor(rgb(96, 78, 226, 0.42))
ctx.setLineWidth(30)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.strokePath()
ctx.restoreGState()
ctx.restoreGState()

// ---- 右下角徽章：薄荷绿圆形 + 向下箭头（"邮件落到这里"） ----
let badgeCenter = CGPoint(x: 742, y: 352)
let badgeR: CGFloat = 132
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: rgb(15, 15, 60, 0.38))
ctx.setFillColor(rgb(52, 205, 145))
ctx.fillEllipse(in: CGRect(x: badgeCenter.x - badgeR, y: badgeCenter.y - badgeR,
                           width: badgeR*2, height: badgeR*2))
ctx.restoreGState()

ctx.saveGState()
let badgePath = CGPath(ellipseIn: CGRect(x: badgeCenter.x - badgeR, y: badgeCenter.y - badgeR,
                                         width: badgeR*2, height: badgeR*2), transform: nil)
ctx.addPath(badgePath)
ctx.clip()
let badgeGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [rgb(110, 232, 176), rgb(38, 190, 132)] as CFArray,
                           locations: [0, 1])!
ctx.drawLinearGradient(badgeGrad,
                       start: CGPoint(x: badgeCenter.x, y: badgeCenter.y + badgeR),
                       end: CGPoint(x: badgeCenter.x, y: badgeCenter.y - badgeR),
                       options: [])
ctx.restoreGState()

// 箭头
let arrow = CGMutablePath()
arrow.move(to: CGPoint(x: badgeCenter.x, y: badgeCenter.y + 62))
arrow.addLine(to: CGPoint(x: badgeCenter.x, y: badgeCenter.y - 40))
arrow.move(to: CGPoint(x: badgeCenter.x - 46, y: badgeCenter.y + 4))
arrow.addLine(to: CGPoint(x: badgeCenter.x, y: badgeCenter.y - 46))
arrow.addLine(to: CGPoint(x: badgeCenter.x + 46, y: badgeCenter.y + 4))
ctx.addPath(arrow)
ctx.setStrokeColor(rgb(255, 255, 255))
ctx.setLineWidth(26)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.strokePath()

NSGraphicsContext.restoreGraphicsState()

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
