//
//  TimeInterval+Formatting.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/15.
//

import Foundation

extension TimeInterval {
    var formattedDuration: String {
        guard !isNaN, !isInfinite else { return "0:00" }
        
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}