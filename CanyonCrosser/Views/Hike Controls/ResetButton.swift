/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The button to reset a hike.
*/

import SwiftUI
import RealityKit

struct ResetButton: View {
    @Environment(AppModel.self) var appModel
    let buttonSize: CGFloat
    @State private var resetProgress: Bool = false

    var body: some View {
        Button {
            resetProgress.toggle()
            appModel.resetHike()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .frame(width: buttonSize, height: buttonSize)
                .symbolEffect(.rotate, options: .speed(4).nonRepeating, value: resetProgress)
        }
        .disabled(appModel.hikePlaybackStateComponent.disableResetButton)
        .disabled(appModel.hikerDragStateComponent.entityBeingDragged || appModel.hikerDragStateComponent.sliderBeingDragged)
    }
}
