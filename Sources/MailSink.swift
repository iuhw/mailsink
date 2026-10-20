//
//  MailSink.swift
//  A tiny macOS helper that takes over the `mailto:` URL scheme so that
//  clicking an email address no longer launches Mail. It simply copies the
//  address to the clipboard and gets out of the way.
//
//  MIT License · https://github.com/iuhw/mailsink
//

import AppKit
import CoreServices

let appVersion = "1.0.0"
let sinkBundleID = "io.github.iuhw.mailsink"
let mailBundleID = "com.apple.mail"
let quietDefaultsKey = "quiet"

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

/// `mailto:a@x.com,b@y.com?subject=Hi` -> `["a@x.com", "b@y.com"]`
func recipients(from urlString: String) -> [String] {
    var s = urlString
    if let colon = s.firstIndex(of: ":") {
        s = String(s[s.index(after: colon)...])
    }
    if let q = s.firstIndex(of: "?") {
        s = String(s[..<q])
    }
    return s
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .map { $0.removingPercentEncoding ?? $0 }
        .filter { !$0.isEmpty }
}

// MARK: - Command line interface

let cliArgs = Array(CommandLine.arguments.dropFirst())

func has(_ flag: String) -> Bool { cliArgs.contains(flag) }

func value(after flag: String) -> String? {
    guard let i = cliArgs.firstIndex(of: flag), cliArgs.count > i + 1 else { return nil }
    return cliArgs[i + 1]
}

let usageText = """
MailSink \(appVersion) — stop clicking an email address from opening Mail.

Usage:
  MailSink --install            Make MailSink the handler for mailto: links
  MailSink --uninstall          Hand mailto: links back to Apple Mail
  MailSink --check              Print the app that currently handles mailto:
  MailSink --quiet on|off       Turn the notification on or off (default: on)
  MailSink --version            Print the version
  MailSink --help               Show this help

With no arguments MailSink behaves as a mailto: receiver: it copies the
recipient address(es) to the clipboard and exits.
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

        let addresses = recipients(from: urlString)
        guard !addresses.isEmpty else { return }
        let joined = addresses.joined(separator: ", ")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(joined, forType: .string)

        let notificationsOn = UserDefaults.standard.object(forKey: quietDefaultsKey) as? Bool ?? true
        if notificationsOn { notify(joined) }
    }

    private func notify(_ address: String) {
        func escaped(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
             .replacingOccurrences(of: "\"", with: "\\\"")
        }
        let script = "display notification \"\(escaped(address))\" "
                   + "with title \"\(escaped(t("邮箱地址已复制", "Email address copied")))\" "
                   + "subtitle \"\(escaped(t("没有打开任何邮件客户端", "No email client was opened")))\""

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
