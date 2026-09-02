// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - Virtual Display HUD & Map Renderer

import Foundation
import CoreVideo
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

public final class VirtualDisplayRenderer {
    public let width: Int
    public let height: Int
    private var pixelBufferPool: CVPixelBufferPool?

    public init(width: Int = 800, height: Int = 384) {
        self.width = width
        self.height = height
        setupPixelBufferPool()
    }

    private func setupPixelBufferPool() {
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pixelBufferPool
        )
    }

    /// Renders the motorcycle dashboard HUD into a CVPixelBuffer
    public func renderHUD(
        speedKmh: Int,
        speedLimit: Int?,
        nextManeuver: String,
        distanceToTurn: String,
        streetName: String,
        heading: Double
    ) -> CVPixelBuffer? {
        guard let pool = pixelBufferPool else { return nil }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        // Flip coordinates for standard top-left origin
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)

        // 1. Dark Motorcycle Theme Background
        context.setFillColor(CGColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        #if os(iOS)
        UIGraphicsPushContext(context)

        // 2. Navigation Top Banner (Turn-by-turn)
        let bannerRect = CGRect(x: 20, y: 15, width: width - 40, height: 90)
        let bannerPath = UIBezierPath(roundedRect: bannerRect, cornerRadius: 16)
        UIColor(red: 0.12, green: 0.15, blue: 0.22, alpha: 0.95).setFill()
        bannerPath.fill()

        // Turn Maneuver Icon & Text
        let manText = nextManeuver as NSString
        let manFont = UIFont.systemFont(ofSize: 28, weight: .bold)
        let manAttributes: [NSAttributedString.Key: Any] = [
            .font: manFont,
            .foregroundColor: UIColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 1.0)
        ]
        manText.draw(at: CGPoint(x: 40, y: 25), withAttributes: manAttributes)

        // Distance to turn & Street Name
        let distText = "\(distanceToTurn) • \(streetName)" as NSString
        let distFont = UIFont.systemFont(ofSize: 20, weight: .medium)
        let distAttributes: [NSAttributedString.Key: Any] = [
            .font: distFont,
            .foregroundColor: UIColor.white
        ]
        distText.draw(at: CGPoint(x: 40, y: 65), withAttributes: distAttributes)

        // 3. Speedometer Section (Left/Center)
        let speedString = "\(speedKmh)" as NSString
        let speedFont = UIFont.systemFont(ofSize: 72, weight: .heavy)
        let speedAttributes: [NSAttributedString.Key: Any] = [
            .font: speedFont,
            .foregroundColor: UIColor.white
        ]
        speedString.draw(at: CGPoint(x: 40, y: height - 120), withAttributes: speedAttributes)

        let kmhLabel = "KM/H" as NSString
        let kmhFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
        let kmhAttributes: [NSAttributedString.Key: Any] = [
            .font: kmhFont,
            .foregroundColor: UIColor(red: 0.6, green: 0.65, blue: 0.75, alpha: 1.0)
        ]
        kmhLabel.draw(at: CGPoint(x: 160, y: height - 75), withAttributes: kmhAttributes)

        // 4. Speed Limit Badge (if available)
        if let limit = speedLimit {
            let limitRect = CGRect(x: 230, y: height - 110, width: 60, height: 60)
            let limitPath = UIBezierPath(ovalIn: limitRect)
            UIColor.white.setFill()
            limitPath.fill()
            UIColor.red.setStroke()
            limitPath.lineWidth = 5
            limitPath.stroke()

            let limitStr = "\(limit)" as NSString
            let limitFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let limitAttr: [NSAttributedString.Key: Any] = [
                .font: limitFont,
                .foregroundColor: UIColor.black
            ]
            let strSize = limitStr.size(withAttributes: limitAttr)
            limitStr.draw(
                at: CGPoint(x: limitRect.midX - strSize.width / 2, y: limitRect.midY - strSize.height / 2),
                withAttributes: limitAttr
            )
        }

        // 5. Compass Heading Indicator
        let headingText = "🧭 \(Int(heading))°" as NSString
        let headingFont = UIFont.systemFont(ofSize: 22, weight: .semibold)
        let headingAttr: [NSAttributedString.Key: Any] = [
            .font: headingFont,
            .foregroundColor: UIColor(red: 0.4, green: 0.85, blue: 0.5, alpha: 1.0)
        ]
        headingText.draw(at: CGPoint(x: width - 150, y: height - 60), withAttributes: headingAttr)

        UIGraphicsPopContext()
        #endif

        return buffer
    }
}
