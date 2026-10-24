import Foundation

enum AppFormatting {
    // App copy and dates stay English while dates retain the user's time zone.
    static let english = Locale(identifier: "en_US_POSIX")
    static let date = Date.FormatStyle.dateTime.day().month(.wide).year().locale(english)
    static let time = Date.FormatStyle.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute().locale(english)
    static let historyDay = Date.FormatStyle.dateTime.weekday(.wide).day().month(.abbreviated).locale(english)
    static let dateAndTime = Date.FormatStyle(date: .abbreviated, time: .shortened).locale(english)
}
