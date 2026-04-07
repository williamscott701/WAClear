import Foundation

struct ConversionSettings: Sendable {
    var targetWidth: Int = Constants.Video.targetWidth
    var targetHeight: Int = Constants.Video.targetHeight
    var videoBitrate: Int = Constants.Video.videoBitrate
    var audioBitrate: Int = Constants.Video.audioBitrate
    var audioSampleRate: Double = Constants.Video.audioSampleRate
    var audioChannels: Int = Constants.Video.audioChannels
    var frameRate: Double = Constants.Video.frameRate
    var maxKeyframeInterval: Int = Constants.Video.maxKeyframeInterval
    var chunkDuration: Double = Constants.Video.chunkDuration
    var addWatermark: Bool = true

    static let `default` = ConversionSettings()
}
