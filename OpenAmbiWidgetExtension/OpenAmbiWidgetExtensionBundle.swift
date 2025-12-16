//
//  OpenAmbiWidgetExtensionBundle.swift
//  OpenAmbiWidgetExtension
//
//  Created by Brian Daly on 27.11.25.
//

import WidgetKit
import SwiftUI

@main
struct OpenAmbiWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        OpenAmbiWidgetExtension()
        OpenAmbiWidgetExtensionControl()
        OpenAmbiWidgetExtensionLiveActivity()
    }
}
