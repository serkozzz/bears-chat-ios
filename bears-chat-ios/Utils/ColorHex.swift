//
//  ColorHex.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 04.04.2026.
//


import SwiftUI
import UIKit

enum ColorHex {
    static func toHex(_ color: Color) -> String? {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return nil
        }

        let red = Int(round(r * 255))
        let green = Int(round(g * 255))
        let blue = Int(round(b * 255))
        let alpha = Int(round(a * 255))

        if alpha < 255 {
            return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
        }

        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    static func fromHex(_ hex: String) -> Color? {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") { value.removeFirst() }

        guard value.count == 6 || value.count == 8 else { return nil }
        guard let int = UInt64(value, radix: 16) else { return nil }

        let r, g, b, a: UInt64
        if value.count == 8 {
            r = (int & 0xFF00_0000) >> 24
            g = (int & 0x00FF_0000) >> 16
            b = (int & 0x0000_FF00) >> 8
            a = int & 0x0000_00FF
        } else {
            r = (int & 0xFF00_00) >> 16
            g = (int & 0x00FF_00) >> 8
            b = int & 0x0000_FF
            a = 255
        }

        return Color(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}
