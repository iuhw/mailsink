<p align="center">
  <img src="docs/icon.png" width="128" alt="MailSink icon">
</p>

<h1 align="center">MailSink</h1>

<p align="center">Stop macOS from launching Mail every time you click an email address.</p>

---

Click an address on a web page, in a PDF, in a note or in a chat app and macOS
hands the `mailto:` link to Apple Mail — which opens a compose window, checks for
new mail, steals focus, and sometimes starts fetching your inbox. There is no
"do nothing" option for `mailto:` anywhere in System Settings, and the picker
that does exist is buried inside Mail's own preferences.

MailSink is a ~250-line app that takes that job instead. When a `mailto:` link
arrives it copies the recipient address(es) to the clipboard, or opens a Gmail
compose window in your browser, or does nothing at all — and then exits. No mail
client opens unless you ask for one. Nothing is sent.

中文说明：[README.zh-CN.md](README.zh-CN.md)

## What it does

| | |
|---|---|
| Click an email address anywhere | Depends on the mode you pick (see below) |
| Default mode (`copy`) | Addresses are copied to the clipboard |
| Notification | "Email address copied — no email client was opened" |
| Mail app | Never launched |
| Background process | None — the app runs for ~0.4s and quits |
| Network access | None |
| Dock icon / menu bar item | None |

`mailto:alice@example.com,bob@example.com?subject=Hi` becomes
`alice@example.com, bob@example.com` — every address is kept, `cc` / `bcc` /
`subject` / `body` parameters are parsed but not forced into your clipboard.

### Modes

| Mode | What a click does |
|---|---|
| `copy` (default) | Copies the recipient addresses to the clipboard |
| `gmail` | Opens `mail.google.com` compose in your default browser, pre-filled with to / cc / bcc / subject / body |
| `silent` | Nothing at all — no clipboard, no notification, no window |

```sh
$APP --mode gmail     # switch
$APP --mode           # print the current mode
```

## Requirements

- macOS 12 or later (Apple Silicon or Intel)
- Xcode Command Line Tools: `xcode-select --install`

The app is compiled on your own Mac from source, so it is signed ad-hoc and
Gatekeeper stays happy. No prebuilt binary is distributed.

## Install

```sh
git clone https://github.com/iuhw/mailsink.git
cd mailsink
make install
```

That builds `~/Applications/MailSink.app`, registers it with Launch Services,
and makes it the handler for `mailto:`.

Verify:

```sh
open 'mailto:hello@example.com'   # clipboard should now hold hello@example.com
```

## Commands

```sh
APP=~/Applications/MailSink.app/Contents/MacOS/MailSink

$APP --check          # who handles mailto: right now
$APP --install        # take over again (e.g. after a Mail update)
$APP --uninstall      # hand mailto: back to Apple Mail
$APP --mode gmail     # copy | gmail | silent
$APP --quiet off      # stop showing the notification
$APP --dry-run 'mailto:a@b.com?subject=Hi'   # see what would happen
$APP --help
```

Or with make: `make install`, `make check`, `make uninstall`.

## Uninstall

```sh
make uninstall        # restores Apple Mail as the mailto: handler and deletes the app
```

Nothing else is written to the system — no launch agents, no login items, no
preference files outside `io.github.iuhw.mailsink`.

## How it works

1. `Info.plist` declares `CFBundleURLTypes` for the `mailto` scheme, which makes
   the bundle eligible to be a URL handler.
2. `LSSetDefaultHandlerForURLScheme("mailto", "io.github.iuhw.mailsink")` points
   the system at MailSink.
3. macOS delivers the link as an Apple Event (`kInternetEventClass` /
   `kAEGetURL`); the app parses the URL and dispatches on the mode — copy to
   `NSPasteboard`, open a Gmail compose URL via `NSWorkspace`, or exit silently —
   optionally firing an `osascript` notification.
4. `LSUIElement` is `true`, so there is no Dock icon and no app switcher entry.

## FAQ

**Is this safe / does it read my mail?**
It has no accounts, no entitlements, no networking code. Read `Sources/MailSink.swift`
— it is one file and about 200 lines.

**Mail took the handler back after an update.**
Re-run `make install` (or `--install`). macOS occasionally rewrites the `mailto:`
association. You can confirm with `--check`.

**I actually want Gmail in the browser instead.**
Use `$APP --mode gmail`. The compose page opens pre-filled with recipients,
cc, bcc, subject and body. It only covers Gmail; the URL is a plain `https://`
link, so it works in whichever browser is your default.

**Can I mix modes — copy sometimes, Gmail sometimes?**
Not per click; the mode is a single setting. If you want a prompt on every
click, Velja or Bumpr do that.

**Why not just remove Mail.app?**
It is a system app and cannot be removed. Deleting its accounts helps only in
that a stray window stays empty.

**Does it interfere with "Share → Email" or Contacts?**
Those also go through `mailto:` and are handled the same way: the address is
copied instead of a draft opening.

## Alternatives

If you would rather route `mailto:` to a webmail provider or pick a mail client
per click, look at [Velja](https://sindresorhus.com/velja) or Bumpr. MailSink is
deliberately narrower: it does one thing and gets out of the way.

## License

[MIT](LICENSE)
