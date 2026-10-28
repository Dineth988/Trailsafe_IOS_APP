//
//  TrailSafeWidgetsLiveActivity.swift
//  TrailSafeWidgets
//
//  Created by Dineth Wickramasinghe on 2026-10-28.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TrailSafeWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TrailSafeWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrailSafeWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension TrailSafeWidgetsAttributes {
    fileprivate static var preview: TrailSafeWidgetsAttributes {
        TrailSafeWidgetsAttributes(name: "World")
    }
}

extension TrailSafeWidgetsAttributes.ContentState {
    fileprivate static var smiley: TrailSafeWidgetsAttributes.ContentState {
        TrailSafeWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TrailSafeWidgetsAttributes.ContentState {
         TrailSafeWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TrailSafeWidgetsAttributes.preview) {
   TrailSafeWidgetsLiveActivity()
} contentStates: {
    TrailSafeWidgetsAttributes.ContentState.smiley
    TrailSafeWidgetsAttributes.ContentState.starEyes
}
