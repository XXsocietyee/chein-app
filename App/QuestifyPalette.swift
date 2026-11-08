import SwiftUI
import UIKit

/// Brand tint with separate light/dark values; keeps native control semantics and shapes.
enum QuestifyPalette {
    static let accent=Color(UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red:248.0/255,green:248.0/255,blue:248.0/255,alpha:1)
        }
        return UIColor(red:51.0/255,green:54.0/255,blue:60.0/255,alpha:1)
    })
}
