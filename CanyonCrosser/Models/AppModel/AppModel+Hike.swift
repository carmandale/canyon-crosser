/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Extension on `AppModel` to set hike components.
*/

import Foundation
import RealityKit
import SwiftUI

extension AppModel {
    // MARK: - Hike State observable components

    /// The following computed properties provide access to the components that house the data associated with the hike.
    /// Access the components through the Observable property for use when views need to stay
    /// up to date with any updates.
    ///
    /// To update views only when they require an update, the app uses multiple components to updated the views
    /// at different intervals.
    ///
    /// In `AppModel+Setup.swift`, `hikerEntity` is created with the required components. If the application is refactored such
    /// that this setup process changes or these components are removed these functions will stop the execution of the app.

    var hikeTimingComponent: HikeTimingComponent {
        get {
            guard let component = hikerEntity.observable.components[HikeTimingComponent.self] else { fatalError() }
            return component
        }
        set { hikerEntity.observable.components[HikeTimingComponent.self] = newValue }
    }

    var hikerProgressComponent: HikerProgressComponent {
        get {
            guard let component = hikerEntity.observable.components[HikerProgressComponent.self] else { fatalError() }
            return component
        }
        set { hikerEntity.observable.components[HikerProgressComponent.self] = newValue }
    }

    var hikePlaybackStateComponent: HikePlaybackStateComponent {
        get {
            guard let component = hikerEntity.observable.components[HikePlaybackStateComponent.self] else { fatalError() }
            return component
        }
        set { hikerEntity.observable.components[HikePlaybackStateComponent.self] = newValue }
    }

    var hikerDragStateComponent: HikerDragStateComponent {
        get {
            guard let component = hikerEntity.observable.components[HikerDragStateComponent.self] else { fatalError() }
            return component
        }
        set { hikerEntity.observable.components[HikerDragStateComponent.self] = newValue }
    }

    // MARK: - Computed States

    var shouldShowHikerElevationView: Bool {
        hikerDragStateComponent.entityBeingDragged || hikerDragStateComponent.sliderBeingDragged
    }

    var shouldAnimateSunlightChange: Bool {
        !hikerDragStateComponent.entityBeingDragged
        && !hikerDragStateComponent.sliderBeingDragged
        && hikerProgressComponent.animation == nil
    }

    var timelineLabels: [TimelineLabel] {
        guard let hike = selectedHike else { return [] }

        // Get the time distance and round up. Given a 1 mph hiking speed, round the miles up to get the hours.
        var hoursInTimeline = hike.length.rounded(.up)
        // Round down the time of departing to start the timeline before departure.
        let roundedStartTime = hikeTimingComponent.departureDate.roundHourDown()

        // Check if the arrival time is on the hour or 15 minutes past. If greater than 15 minutes past the hour,
        // add an additional hour to the timeline to see the weather for this additional hour.
        // This results in a slider that could show 2 hours of additional time causing the accuracy
        // of the slider time position and hiker percentage to be inaccurate.
        // If a hike ends at 7:20, when the progress is at 100 percent, the slider will be at 8:00.
        if hikeTimingComponent.departureDate.addingTimeInterval(TimeInterval(hoursInTimeline) * .oneHourInSeconds).minutes() > 15 {
            hoursInTimeline += 1
        }

        return (0...Int(hoursInTimeline)).map { hour in
            let labelTime = roundedStartTime.addingTimeInterval(TimeInterval(hour) * .oneHourInSeconds)

            return TimelineLabel(
                time: labelTime,
                weather: MockData.weather[labelTime.hour()]
            )
        }
    }

    // MARK: - Hike Timing Component functions

    func configureTimingForHike(hike: Hike) {
        hikeTimingComponent.hikeLength = hike.length

        // Reset the rest stop durations.
        hikeTimingComponent.restStopRestDurations.removeAll()

        // Reset the departure and arrival times when selecting a new hike.
        hikeTimingComponent.departureDate = MockData.departureTime
    }

    func getRestDuration(for location: RestStopLocation) -> Int {
        hikeTimingComponent.restStopRestDurations[location] ?? 0
    }

    func setRestDuration(_ rest: Int, for location: RestStopLocation) {
        hikeTimingComponent.restStopRestDurations[location] = rest
    }

    // MARK: - Hike Progress Component functions

    func sliderThumbDrag(percentage: Float) {
        // Prevent simultaneous entity and slider dragging.
        guard !hikerDragStateComponent.entityBeingDragged else {
            return
        }

        // When a drag starts, add the elevation view and fade out the clouds.
        if !hikerDragStateComponent.sliderBeingDragged {
            hikerDragStateComponent.sliderBeingDragged = true
            fadeOutClouds()
            addHikerElevationView()
        }

        animateProgress(to: percentage)
    }

    func sliderDragCompleted() {
        hikerDragStateComponent.sliderBeingDragged = false
        fadeInClouds()
        removeHikerElevationView()
        updateResetButtonState()
    }

    func sliderTapped(percentage: Float) {
        animateProgress(to: percentage)
    }

    private func animateProgress(to value: Float) {
        if hikePlaybackStateComponent.disableResetButton {
            hikePlaybackStateComponent.disableResetButton = false
        }

        hikerProgressComponent.animation = (toValue: value, fromValue: hikerProgressComponent.hikeProgress, elapsedTime: 0)
    }

    // MARK: - Hike Playback State Component functions

    func toggleHikePlaybackState() {
        // When the playback button is tapped with a completed hike, reset the progress to zero.
        if hikerProgressComponent.hikeProgress == 1.0 {
            hikerProgressComponent.hikeProgress = 0.0
            hikePlaybackStateComponent.disableResetButton = true
        }

        hikePlaybackStateComponent.isPaused.toggle()

        // After toggling playback, enable the reset button if it was disabled.
        if hikePlaybackStateComponent.disableResetButton {
            hikePlaybackStateComponent.disableResetButton = false
        }
    }

    func resetHike() {
        hikePlaybackStateComponent.isPaused = true
        hikePlaybackStateComponent.disableResetButton = true
        hikerProgressComponent.hikeProgress = 0.0
    }

    func updateResetButtonState() {
        if hikerProgressComponent.hikeProgress == 0.0 {
            // Make the the Reset button unavailable if there's no additional progress and it's currently available.
           if !hikePlaybackStateComponent.disableResetButton {
               hikePlaybackStateComponent.disableResetButton = true
            }
        } else {
            // Make the reset button available if there's an active hike and the Reset button is currently unavailable.
            if hikePlaybackStateComponent.disableResetButton {
                hikePlaybackStateComponent.disableResetButton = false
            }
        }
    }

    // MARK: - Hiker Drag Gesture

    func hikerDragChanged(event: EntityTargetValue<DragGesture.Value>) {
        // Prevent simultaneous slider and entity dragging.
        guard !hikerDragStateComponent.sliderBeingDragged else {
            return
        }

        // If the entity wasn't previously dragged, this is the start of a new drag.
        if !hikerDragStateComponent.entityBeingDragged {
            // Store the initial hike progress when the drag began.
            initialHikeProgressOnDrag = hikerProgressComponent.hikeProgress

            fadeOutClouds()
            addHikerElevationView()
        }

        // Store that a drag on the hiker entity is in progress.
        hikerDragStateComponent.entityBeingDragged = true

        // Get the necessary start and end entities for the trail.
        guard let hike = selectedHike else { return }
        guard
            let startEntity = grandCanyonEntity.childAt(path: hike.trailStartEntityName),
            let endEntity = grandCanyonEntity.childAt(path: hike.trailEndEntityName)
        else {
            grandCanyonEntity.printTree()
            assertionFailure("Failed to load '\(hike.trailStartEntityName)' and '\(hike.trailEndEntityName)'")
            return
        }

        let currentDragLocation = event.convert(event.location3D, from: .local, to: grandCanyonEntity)
        let startDragLocation = event.convert(event.startLocation3D, from: .local, to: grandCanyonEntity)
        hikerProgressComponent.hikeProgress = calculateHikeProgressFromDrag(
            trailVector: endEntity.position(relativeTo: grandCanyonEntity) - startEntity.position(relativeTo: grandCanyonEntity),
            dragVector: currentDragLocation - startDragLocation
        )
    }

    /// Returns the hike progress that results from the given drag vector.
    /// - Parameters:
    ///   - trailVector: The vector from the Grand Canyon to the start of the hike.
    ///   - dragVector: The drag vector from the start of the drag to the current location of the drag.
    ///   - hikerDragMagnitude: How much the drag distance affects the change of the returned value.
    ///
    /// - Returns: The new hike progress value for the drag parameters.
    private func calculateHikeProgressFromDrag(
        trailVector: SIMD3<Float>,
        dragVector: SIMD3<Float>,
        hikerDragMagnitude: Float = 0.75
    ) -> Float {
        // Project the `dragVector` onto the `trailVector`.
        let dragOnTrail = (dot(dragVector, trailVector) / dot(trailVector, trailVector)) * normalize(trailVector)

        /// Length of the drag along the trail, as a percent, to the length of the trail.
        let percentDragOnTrail = length(dragOnTrail) / length(trailVector)

        // Use the reverse trail vector if the hiker is hiking back.
        let currentTrailDirectionVector = initialHikeProgressOnDrag < 0.5 ? trailVector : -trailVector

        // Calculate the change value using the `hikerDragMagnitude` and the direction of the drag vector.
        let changeValueForDrag = Float(
            signOf: dot(dragOnTrail, currentTrailDirectionVector),
            magnitudeOf: percentDragOnTrail * hikerDragMagnitude
        )

        // Return the new progress given the change value and the initial progress at the start of the drag.
        return (changeValueForDrag + initialHikeProgressOnDrag).clamped(to: 0.0...1.0)
    }

    func hikerDragEnded() {
        hikerDragStateComponent.entityBeingDragged = false
        fadeInClouds()
        updateResetButtonState()
    }
}

