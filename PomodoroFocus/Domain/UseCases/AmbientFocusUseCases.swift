import Foundation

@MainActor
protocol PlayAmbientSoundUseCaseProtocol {
    func execute(fadeIn: Bool) async
}

@MainActor
protocol StopAmbientSoundUseCaseProtocol {
    func execute(fadeOut: Bool) async
}

@MainActor
protocol UpdateTrackVolumeUseCaseProtocol {
    func execute(sound: AmbientSound, volume: Float)
    func toggleTrack(sound: AmbientSound)
}

@MainActor
protocol ActivateFocusModeUseCaseProtocol {
    func execute() async
}

@MainActor
protocol DeactivateFocusModeUseCaseProtocol {
    func execute() async
}

@MainActor
struct PlayAmbientSoundUseCase: PlayAmbientSoundUseCaseProtocol {
    let coordinator: FocusModeCoordinator

    func execute(fadeIn: Bool) async {
        coordinator.startAudio(fadeIn: fadeIn)
    }
}

@MainActor
struct StopAmbientSoundUseCase: StopAmbientSoundUseCaseProtocol {
    let coordinator: FocusModeCoordinator

    func execute(fadeOut: Bool) async {
        coordinator.stopAudio(fadeOut: fadeOut)
    }
}

@MainActor
struct UpdateTrackVolumeUseCase: UpdateTrackVolumeUseCaseProtocol {
    let coordinator: FocusModeCoordinator

    func execute(sound: AmbientSound, volume: Float) {
        coordinator.setVolume(volume, for: sound)
    }

    func toggleTrack(sound: AmbientSound) {
        coordinator.toggleTrack(sound)
    }
}

@MainActor
struct ActivateFocusModeUseCase: ActivateFocusModeUseCaseProtocol {
    let coordinator: FocusModeCoordinator

    func execute() async {
        await coordinator.activate()
    }
}

@MainActor
struct DeactivateFocusModeUseCase: DeactivateFocusModeUseCaseProtocol {
    let coordinator: FocusModeCoordinator

    func execute() async {
        await coordinator.deactivate()
    }
}
