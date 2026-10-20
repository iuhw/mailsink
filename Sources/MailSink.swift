//
//  MailSink.swift
//  A tiny macOS helper that takes over the `mailto:` URL scheme so that
//  clicking an email address no longer launches Mail. It copies the address,
//  opens Gmail in your browser, or does nothing — your choice.
//
//  MIT License · https://github.com/iuhw/mailsink
//

import AppKit
import CoreServices

let appVersion = "1.1.0"
let sinkBundleID = "io.github.iuhw.mailsink"
let mailBundleID = "com.apple.mail"
let quietDefaultsKey = "quiet"
let modeDefaultsKey = "mode"

/// What to do with an incoming `mailto:` link.
enum Mode: String {
    case copy    // copy the address(es) to the clipboard
    case gmail   // open Gmail's compose page in the default browser
    case silent  // do nothing at all

    static var current: Mode {
        let raw = UserDefaults.standard.string(forKey: modeDefaultsKey) ?? Mode.copy.rawValue
        return Mode(rawValue: raw) ?? .copy
    }
}

/// Minimal two-language string, following the user's preferred language.
func t(_ zh: String, _ en: String) -> String {
    let lang = (Locale.preferredLanguages.first ?? "en").lowercased()
    return lang.hasPrefix("zh") ? zh : en
}

// MARK: - Launch Services

func currentHandler() -> String {
    if let h = LSCopyDefaultHandlerForURLScheme("mailto" as CFString)?.takeRetainedValue() as String? {
        return h
    }
    return "<none>"
}

@discardableResult
func setHandler(_ bundleID: String) -> OSStatus {
    LSSetDefaultHandlerForURLScheme("mailto" as CFString, bundleID as CFString)
}

// MARK: - mailto parsing

struct MailLink {
    let recipients: [String]
    let cc: [String]
    let bcc: [String]
    let subject: String?
    let body: String?

    init?(urlString: String) {
        guard let comps = URLComponents(string: urlString),
              comps.scheme?.lowercased() == "mailto" else { return nil }

        func list(_ raw: String?) -> [String] {
            guard let raw = raw, !raw.isEmpty else { return [] }
            return raw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        let path = comps.percentEncodedPath.removingPercentEncoding ?? comps.path
        recipients = list(path)

        let items = comps.queryItems ?? []
        func query(_ name: String) -> String? {
            items.first { $0.name.lowercased() == name }?.value
        }
        cc = list(query("cc"))
        bcc = list(query("bcc"))
        subject = query("subject")
        body = query("body")
    }

    /// Addresses to put in a "To" field.
    var toLine: String { recipients.joined(separator: ", ") }

    var gmailComposeURL: URL? {
        guard !recipients.isEmpty || !cc.isEmpty || !bcc.isEmpty else { return nil }
        var components = URLComponents(string: "https://mail.google.com/mail/")!
        var items = [
            URLQueryItem(name: "view", value: "cm"),
            URLQueryItem(name: "fs", value: "1"),
        ]
        if !recipients.isEmpty { items.append(URLQueryItem(name: "to", value: recipients.joined(separator: ","))) }
        if !cc.isEmpty { items.append(URLQueryItem(name: "cc", value: cc.joined(separator: ","))) }
        if !bcc.isEmpty { items.append(URLQueryItem(name: "bcc", value: bcc.joined(separator: ","))) }
        if let s = subject, !s.isEmpty { items.append(URLQueryItem(name: "su", value: s)) }
        if let b = body, !b.isEmpty { items.append(URLQueryItem(name: "body", value: b)) }
        components.queryItems = items
        return components.url
    }
}

// MARK: - Command line interface

let cliArgs = Array(CommandLine.arguments.dropFirst())

func has(_ flag: String) -> Bool { cliArgs.contains(flag) }

func value(after flag: String) -> String? {
    guard let i = cliArgs.firstIndex(of: flag), cliArgs.count > i + 1 else { return nil }
    let next = cliArgs[i + 1]
    return next.hasPrefix("--") ? nil : next
}

let usageText = """
MailSink \(appVersion) — stop clicking an email address from opening Mail.

Usage:
  MailSink --install            Make MailSink the handler for mailto: links
  MailSink --uninstall          Hand mailto: links back to Apple Mail
  MailSink --check              Print the app that currently handles mailto:
  MailSink --mode [name]        Show or set what happens on a click:
                                  copy    copy the address to the clipboard (default)
                                  gmail   open Gmail's compose page in your browser
                                  silent  do nothing at all
  MailSink --quiet on|off       Turn the notification on or off (default: on)
  MailSink --dry-run <url>      Show what a mailto: link would do, without doing it
  MailSink --version            Print the version
  MailSink --help               Show this help

With no arguments MailSink behaves as a mailto: receiver and exits.
"""

if has("--help") || has("-h") {
    print(usageText)
    exit(0)
}

if has("--version") {
    print(appVersion)
    exit(0)
}

if has("--check") {
    print(currentHandler())
    exit(0)
}

if has("--install") {
    let status = setHandler(sinkBundleID)
    guard status == noErr else {
        FileHandle.standardError.write("could not set handler (OSStatus \(status))\n".data(using: .utf8)!)
        exit(1)
    }
    print(t("mailto: 现在由 MailSink 接管", "mailto: is now handled by MailSink"))
    exit(0)
}

if has("--uninstall") {
    let status = setHandler(mailBundleID)
    guard status == noErr else {
        FileHandle.standardError.write("could not reset handler (OSStatus \(status))\n".data(using: .utf8)!)
        exit(1)
    }
    print(t("mailto: 已交还给 Mail.app", "mailto: was handed back to Mail.app"))
    exit(0)
}

if let raw = value(after: "--quiet") {
    let enabled = !["off", "false", "0", "no"].contains(raw.lowercased())
    UserDefaults.standard.set(enabled, forKey: quietDefaultsKey)
    print(enabled
          ? t("通知已开启", "notifications enabled")
          : t("通知已关闭", "notifications disabled"))
    exit(0)
}

if has("--mode") {
    guard let raw = value(after: "--mode") else {
        print(Mode.current.rawValue)
        exit(0)
    }
    guard let mode = Mode(rawValue: raw.lowercased()) else {
        FileHandle.standardError.write("unknown mode: \(raw) (expected copy, gmail or silent)\n".data(using: .utf8)!)
        exit(1)
    }
    UserDefaults.standard.set(mode.rawValue, forKey: modeDefaultsKey)
    print(t("当前模式：\(mode.rawValue)", "mode set to \(mode.rawValue)"))
    exit(0)
}

if let raw = value(after: "--dry-run") {
    guard let link = MailLink(urlString: raw) else {
        FileHandle.standardError.write("not a mailto: link\n".data(using: .utf8)!)
        exit(2)
    }
    print("mode:       \(Mode.current.rawValue)")
    print("recipients: \(link.toLine.isEmpty ? "-" : link.toLine)")
    print("cc:         \(link.cc.isEmpty ? "-" : link.cc.joined(separator: ", "))")
    print("subject:    \(link.subject ?? "-")")
    switch Mode.current {
    case .copy:
        print("action:     copy \(link.toLine.isEmpty ? "nothing" : "\"\(link.toLine)\"") to the clipboard")
    case .gmail:
        print("action:     open \(link.gmailComposeURL?.absoluteString ?? "nothing (no address)")")
    case .silent:
        print("action:     nothing")
    }
    exit(0)
}

// MARK: - Runtime: behave as the mailto: receiver

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var didHandleURL = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor,
                                      withReply reply: NSAppleEventDescriptor) {
        if let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue {
            sink(urlString: urlString)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { sink(urlString: url.absoluteString) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launched from Finder with no link attached: leave quietly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !self.didHandleURL { NSApp.terminate(nil) }
        }
    }

    private func sink(urlString: String) {
        guard !didHandleURL else { return }
        didHandleURL = true

        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { NSApp.terminate(nil) }
        }

        guard let link = MailLink(urlString: urlString) else { return }

        switch Mode.current {
        case .silent:
            return

        case .copy:
            guard !link.toLine.isEmpty else { return }
            copyToPasteboard(link.toLine)
            notify(link.toLine,
                   title: t("邮箱地址已复制", "Email address copied"),
                   subtitle: t("没有打开任何邮件客户端", "No email client was opened"))

        case .gmail:
            if let url = link.gmailComposeURL, NSWorkspace.shared.open(url) {
                notify(link.toLine,
                       title: t("已在浏览器打开 Gmail 写信页", "Opened Gmail compose in your browser"),
                       subtitle: link.toLine)
            } else if !link.toLine.isEmpty {
                // No browser, or nothing to write to: fall back to the clipboard.
                copyToPasteboard(link.toLine)
                notify(link.toLine,
                       title: t("邮箱地址已复制", "Email address copied"),
                       subtitle: t("未能打开浏览器", "Could not open the browser"))
            }
        }
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func notify(_ body: String, title: String, subtitle: String) {
        let notificationsOn = UserDefaults.standard.object(forKey: quietDefaultsKey) as? Bool ?? true
        guard notificationsOn else { return }

        func escaped(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
             .replacingOccurrences(of: "\"", with: "\\\"")
        }
        let script = "display notification \"\(escaped(body))\" "
                   + "with title \"\(escaped(title))\" "
                   + "subtitle \"\(escaped(subtitle))\""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.prohibited)
application.run()
