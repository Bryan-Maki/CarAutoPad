import Foundation

public final class AapServiceDiscoveryResponseMessage {
    public static func make(
        screenConfig: HeadUnitScreenConfig = HeadUnitScreenConfig.shared,
        fpsLimit: Int = 60,
        rightHandDrive: Bool = false,
        useGps: Bool = true,
        useMic: Bool = true,
        requestedDpi: Int? = nil,
        vehicleMake: String = "Apple",
        vehicleModel: String = "iPad",
        vehicleYear: String = "2024",
        vehicleId: String = "iPad-CarAutoPad",
        headUnitMake: String = "CarAutoPad",
        headUnitModel: String = "CarAutoPad",
        enableAudioSink: Bool = ProjectionSettings.isAudioSinkEnabled
    ) -> AapMessage {
        var services: [ControlService] = []

        if screenConfig.screenWidthPx <= 0 || screenConfig.screenHeightPx <= 0 {
            let dims = HeadUnitScreenConfig.currentIpadDimensions()
            if dims.width > 0 && dims.height > 0 {
                screenConfig.initScreen(
                    width: dims.width,
                    height: dims.height,
                    fitMode: ProjectionSettings.videoFitMode,
                    requestedResolution: ProjectionSettings.resolution
                )
            }
        }

        var sensorTypes: [ControlService.SensorSourceService.Sensor] = [
            ControlService.SensorSourceService.Sensor(type: .drivingStatus),
            ControlService.SensorSourceService.Sensor(type: .night)
        ]
        if useGps {
            sensorTypes.append(ControlService.SensorSourceService.Sensor(type: .location))
        }
        let sensorSource = ControlService.SensorSourceService(sensors: sensorTypes)
        services.append(ControlService(id: UInt32(Channel.ID_SEN), sensorSourceService: sensorSource))

        let negotiatedRes = screenConfig.negotiatedResolutionType
        let phoneWidthMargin = screenConfig.getWidthMargin()
        let phoneHeightMargin = screenConfig.getHeightMargin()
        let effectiveRequestedDpi = requestedDpi ?? screenConfig.announcedDensity
        let densityDecision = screenConfig.densityDecision(requestedDpi: effectiveRequestedDpi)
        let par = screenConfig.getPixelAspectRatioE4()

        screenConfig.isResolutionLocked = true
        screenConfig.recordAnnouncedMargins(widthMargin: phoneWidthMargin, heightMargin: phoneHeightMargin)
        screenConfig.recordAnnouncedCanvas()

        let is30Fps = (fpsLimit == 30 || fpsLimit == ProjectionFpsLimit.fps30.rawValue)
        let frameRateType: ControlService.MediaSinkService.VideoConfiguration.VideoFrameRateType = is30Fps ? ._30 : ._60

        let userPref = ProjectionSettings.videoCodecPreference
        let prefersHevc = (userPref == .hevc)
        let isHighRes = (negotiatedRes == ._2560x1440 || negotiatedRes == ._3840x2160 || negotiatedRes == ._1440x2560 || negotiatedRes == ._2160x3840)
        let effectiveCodec: MediaCodecType = (prefersHevc || isHighRes)
            ? .mediaCodecVideoH265
            : .mediaCodecVideoH264Bp

        let videoConfig = ControlService.MediaSinkService.VideoConfiguration(
            codecResolution: negotiatedRes,
            frameRate: frameRateType,
            marginWidth: UInt32(phoneWidthMargin),
            marginHeight: UInt32(phoneHeightMargin),
            density: UInt32(densityDecision.announced),
            decoderAdditionalDepth: 8,
            pixelAspectRatioE4: UInt32(par),
            videoCodecType: effectiveCodec
        )
        screenConfig.announcedVideoConfigs = [videoConfig]

        let mediaSink = ControlService.MediaSinkService(
            availableType: effectiveCodec,
            audioType: .none,
            videoConfigs: [videoConfig],
            availableWhileInCall: true
        )
        services.append(ControlService(id: UInt32(Channel.ID_VID), mediaSinkService: mediaSink))

        let touchConfig = ControlService.InputSourceService.TouchConfig(
            width: UInt32(screenConfig.getNegotiatedWidth()),
            height: UInt32(screenConfig.getNegotiatedHeight())
        )
        let supportedKeycodes: [UInt32] = [
            1, 2, 3, 4, 5, 6,
            7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18,
            19, 20, 21, 22, 23, 24, 25,
            61, 62, 66, 79, 81, 84, 85, 86, 87, 88,
            126, 127, 224, 264, 265, 267, 268, 269, 270, 271,
            65536, 65537, 65538
        ]
        let inputService = ControlService.InputSourceService(
            keycodesSupported: supportedKeycodes,
            touchscreen: touchConfig,
            touchpad: nil
        )
        services.append(ControlService(id: UInt32(Channel.ID_INP), inputSourceService: inputService))

        let userAudioPref = ProjectionSettings.audioCodecPreference
        let announcedAudioCodec: MediaCodecType = (userAudioPref == .aac)
            ? .mediaCodecAudioAacLc
            : .mediaCodecAudioPcm

        let audio2Sink = ControlService.MediaSinkService(
            availableType: announcedAudioCodec,
            audioType: .system,
            audioConfigs: [AudioConfigs.get(channel: Channel.ID_AU2)]
        )
        services.append(ControlService(id: UInt32(Channel.ID_AU2), mediaSinkService: audio2Sink))

        if AudioSinkAnnouncementPolicy.announcesMediaAndSpeech(sinkEnabled: enableAudioSink) {
            let audio1Sink = ControlService.MediaSinkService(
                availableType: announcedAudioCodec,
                audioType: .speech,
                audioConfigs: [AudioConfigs.get(channel: Channel.ID_AU1)]
            )
            services.append(ControlService(id: UInt32(Channel.ID_AU1), mediaSinkService: audio1Sink))

            let audio0Sink = ControlService.MediaSinkService(
                availableType: announcedAudioCodec,
                audioType: .media,
                audioConfigs: [AudioConfigs.get(channel: Channel.ID_AUD)]
            )
            services.append(ControlService(id: UInt32(Channel.ID_AUD), mediaSinkService: audio0Sink))
        }

        if useMic {
            let micConfig = AudioConfiguration(
                sampleRate: UInt32(MicCaptureFormat.SAMPLE_RATE_HZ),
                numberOfBits: UInt32(MicCaptureFormat.BITS),
                numberOfChannels: UInt32(MicCaptureFormat.CHANNELS)
            )
            let micSource = ControlService.MediaSourceService(
                type: .mediaCodecAudioPcm,
                audioConfig: micConfig,
                availableWhileInCall: true
            )
            services.append(ControlService(id: UInt32(Channel.ID_MIC), mediaSourceService: micSource))
        }

        services.append(ControlService(
            id: UInt32(Channel.ID_MPB),
            mediaPlaybackService: ControlService.MediaPlaybackStatusService()
        ))

        let navService = ControlService.NavigationStatusService(
            minimumIntervalMs: 1000,
            type: .imageCodesOnly
        )
        services.append(ControlService(id: UInt32(Channel.ID_NAV), navigationStatusService: navService))

        let effectiveVehicleType: Int32 = 3
        let effectiveVehicleId = vehicleId.hasSuffix("-moto") ? vehicleId : "\(vehicleId)-moto"

        let huInfo = HeadUnitInfo(
            make: vehicleMake,
            model: vehicleModel,
            year: vehicleYear,
            vehicleId: effectiveVehicleId,
            headUnitMake: headUnitMake,
            headUnitModel: headUnitModel,
            headUnitSoftwareBuild: "1",
            headUnitSoftwareVersion: "0.1.0",
            vehicleType: effectiveVehicleType
        )

        let response = ServiceDiscoveryResponseProto(
            services: services,
            make: vehicleMake,
            model: vehicleModel,
            year: vehicleYear,
            vehicleId: effectiveVehicleId,
            driverPosition: rightHandDrive ? .right : .left,
            headUnitMake: headUnitMake,
            headUnitModel: headUnitModel,
            headUnitSoftwareBuild: "1",
            headUnitSoftwareVersion: "0.1.0",
            canPlayNativeMediaDuringVr: false,
            displayName: "CarAutoPad",
            headunitInfo: huInfo
        )

        return AapMessage(
            channel: Int(Channel.ID_CTR),
            type: Int(ControlMsgType.messageServiceDiscoveryResponse.rawValue),
            proto: response
        )
    }
}
