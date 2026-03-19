import CoreAudio
import Foundation

struct DefaultAudioOutputConfiguration: Equatable {
    let sampleRate: Double

    var roundedSampleRate: Int {
        Int(sampleRate.rounded())
    }

    static func current() -> DefaultAudioOutputConfiguration? {
        guard let deviceID = defaultOutputDeviceID(),
              let sampleRate = nominalSampleRate(for: deviceID),
              sampleRate > 0 else {
            return nil
        }

        return DefaultAudioOutputConfiguration(sampleRate: sampleRate)
    }

    private static func defaultOutputDeviceID() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioObjectID(bitPattern: 0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        guard status == noErr, deviceID != AudioObjectID(bitPattern: 0) else {
            return nil
        }

        return deviceID
    }

    private static func nominalSampleRate(for deviceID: AudioObjectID) -> Double? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var sampleRate = Float64.zero
        var size = UInt32(MemoryLayout<Float64>.size)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &sampleRate
        )

        guard status == noErr else {
            return nil
        }

        return sampleRate
    }
}
