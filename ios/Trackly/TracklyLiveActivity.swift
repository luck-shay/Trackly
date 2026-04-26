//
//  TracklyLiveActivity.swift
//  Trackly
//
//  Created by Lakshay Goel on 26/04/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TracklyAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TracklyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TracklyAttributes.self) { context in
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

extension TracklyAttributes {
    fileprivate static var preview: TracklyAttributes {
        TracklyAttributes(name: "World")
    }
}

extension TracklyAttributes.ContentState {
    fileprivate static var smiley: TracklyAttributes.ContentState {
        TracklyAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TracklyAttributes.ContentState {
         TracklyAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TracklyAttributes.preview) {
   TracklyLiveActivity()
} contentStates: {
    TracklyAttributes.ContentState.smiley
    TracklyAttributes.ContentState.starEyes
}
