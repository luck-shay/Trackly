//
//  TracklyBundle.swift
//  Trackly
//
//  Created by Lakshay Goel on 26/04/26.
//

import WidgetKit
import SwiftUI

@main
struct TracklyBundle: WidgetBundle {
    var body: some Widget {
        Trackly()
        TracklyControl()
        TracklyLiveActivity()
    }
}
