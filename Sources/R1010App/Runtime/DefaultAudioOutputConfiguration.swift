import CoreAudio
import Foundation

struct DefaultAudioOutputConfiguration: Equatable {
    let deviceName: String
    let sampleRate: Double

    var roundedSampleRate: Int {
        Int(sampleRate.rounded())
    }

    static func current() -> DefaultAudioOutputConfiguration? {
        guard let deviceID = defaultOutputDeviceID(),
              let deviceName = deviceName(for: deviceID),
              let sampleRate = actualSampleRate(for: deviceID) ?? nominalSampleRate(for: deviceID),
              sampleRate > 0 else {
            return nil
        }

        return DefaultAudioOutputConfiguration(
            deviceName: deviceName,
            sampleRate: sampleRate
        )
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
        float64Property(
            selector: kAudioDevicePropertyNominalSampleRate,
            for: deviceID
        )
    }

    private static func actualSampleRate(for deviceID: AudioObjectID) -> Double? {
        float64Property(
            selector: kAudioDevicePropertyActualSampleRate,
            for: deviceID
        )
    }

    private static func deviceName(for deviceID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString?>.size)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &name
        )

        let resolvedName = name as String

        guard status == noErr, !resolvedName.isEmpty else {
            return nil
        }

        return resolvedName
    }

    private static func float64Property(
        selector: AudioObjectPropertySelector,
        for deviceID: AudioObjectID
    ) -> Double? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
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
