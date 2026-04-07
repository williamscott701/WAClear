import Foundation
import CoreGraphics

enum Constants {
    enum Video {
        static let targetWidth = 960
        static let targetHeight = 1704
        static let videoBitrate = 1_800_000
        static let audioBitrate = 128_000
        static let audioSampleRate: Double = 44100
        static let audioChannels = 2
        static let frameRate: Double = 30
        static let maxKeyframeInterval = 60
        static let chunkDuration: Double = 60.0
        static let maxFileSizeBytes = 16 * 1024 * 1024
    }

    enum StoreKit {
        static let monthlyProductID = "com.waclear.premium.monthly"
    }

    enum Trial {
        /// Calendar days the free trial lasts.
        static let durationDays = 3
        /// Max processings allowed per calendar day during the trial.
        static let dailyProcessingLimit = 3
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
