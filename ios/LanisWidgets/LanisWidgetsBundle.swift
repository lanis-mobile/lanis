import WidgetKit
import SwiftUI

@main
@available(iOSApplicationExtension 16.0, *)
struct LanisWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StundenplanWidget()
        VertretungsWidget()
        KalenderWidget()
        NachrichtenWidget()
        if #available(iOSApplicationExtension 16.2, *) {
            StundenLiveActivityWidget()
        }
    }
}
