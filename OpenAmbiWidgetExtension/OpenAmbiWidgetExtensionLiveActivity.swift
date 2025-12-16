//
//  OpenAmbiWidgetExtensionLiveActivity.swift
//  OpenAmbiWidgetExtension
//
//  Created by Brian Daly on 27.11.25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct OpenAmbiWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct OpenAmbiWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OpenAmbiWidgetExtensionAttributes.self) { context in
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

extension OpenAmbiWidgetExtensionAttributes {
    fileprivate static var preview: OpenAmbiWidgetExtensionAttributes {
        OpenAmbiWidgetExtensionAttributes(name: "World")
    }
}

extension OpenAmbiWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: OpenAmbiWidgetExtensionAttributes.ContentState {
        OpenAmbiWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: OpenAmbiWidgetExtensionAttributes.ContentState {
         OpenAmbiWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: OpenAmbiWidgetExtensionAttributes.preview) {
   OpenAmbiWidgetExtensionLiveActivity()
} contentStates: {
    OpenAmbiWidgetExtensionAttributes.ContentState.smiley
    OpenAmbiWidgetExtensionAttributes.ContentState.starEyes
}
