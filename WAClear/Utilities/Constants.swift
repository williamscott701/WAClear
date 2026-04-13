import Foundation
import CoreGraphics

enum Constants {
    enum Video {
        // Portrait defaults — VideoProcessor overrides these dynamically per source orientation.
        // Targeting 720p keeps us well under WhatsApp's 16 MB / 30s limit while preserving HD clarity.
        static let targetWidth = 720
        static let targetHeight = 1280
        static let videoBitrate = 1_200_000   // 1.2 Mbps: minimises double-compression artefacts
        static let audioBitrate = 96_000
        static let audioSampleRate: Double = 44100
        static let audioChannels = 2
        static let frameRate: Double = 30
        static let maxKeyframeInterval = 30   // 1-second GOPs for better seek & WhatsApp compat
        static let chunkDuration: Double = 30.0  // WhatsApp Status hard cap is 30 s
    }

    enum StoreKit {
        static let monthlyProductID = "com.waclear.premium.monthly"
        static let yearlyProductID  = "com.waclear.premium.yearly"
        static let allProductIDs    = [monthlyProductID, yearlyProductID]
    }

    enum UI {
        static let cornerRadius: CGFloat = 16
        static let cardCornerRadius: CGFloat = 12
        static let gradientStart = "GradientStart"
        static let gradientEnd = "GradientEnd"
    }

    enum Watermark {
        static let text = "WAClear"
        static let opacity: CGFloat = 0.45
    }
}
