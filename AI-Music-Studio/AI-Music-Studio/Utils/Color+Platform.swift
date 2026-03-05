import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Color {
    /// 跨平台：控件/卡片背景色
    static var appControlBackground: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
    
    /// 跨平台：页面/文本背景色
    static var appTextBackground: Color {
        #if os(macOS)
        return Color(NSColor.textBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
}
