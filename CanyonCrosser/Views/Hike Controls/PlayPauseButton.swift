/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The button to play or pause a hike.
*/

import SwiftUI
import RealityKit

struct PlayPauseButton: View {
    @Environment(AppModel.self) var appModel
    let buttonSize: CGFloat

    var body: some View {
        Button {
            appModel.toggleHikePlaybackState()
        } label: {
            Image(systemName: appModel.hikePlaybackStateComponent.isPaused ? "play.fill" : "pause.fill")
                .frame(width: buttonSize, height: buttonSize)
                .contentTransition(.symbolEffect(.replace))
        }
        .disabled(appModel.hikerDragStateComponent.sliderBeingDragged || appModel.hikerDragStateComponent.entityBeingDragged)
    }
}

