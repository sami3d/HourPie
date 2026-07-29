# HourPie 🥧

A tiny macOS menu bar clock that shows the current hour draining away as a pie — like a [Time Timer](https://www.timetimer.com/), but for the clock hour.

At the top of every hour the pie is full. As the minutes pass it drains away, and at the next hour it refills. Forever, like a clock.

![HourPie at 100%, 75%, 50%, 25%, and 8% of the hour remaining](docs/preview.png)

*The icon at 60, 45, 30, 15, and 5 minutes left in the hour.*

## Features

- Lives entirely in the menu bar — no Dock icon, no windows
- Template icon, so it adapts to light and dark menu bars automatically
- Click it to see the exact time left in the hour (`42:17 left this hour`)
- Optional **Launch at Login**
- Zero dependencies, ~140 lines of Swift, negligible CPU

## Install

### Download

Grab `HourPie.app.zip` from the [latest release](https://github.com/sami3d/HourPie/releases/latest), unzip, and drag `HourPie.app` into `/Applications`.

The app is ad-hoc signed (no Apple Developer account), so the first launch needs one extra step: **right-click the app → Open → Open**. Or clear the quarantine flag from Terminal:

```bash
xattr -d com.apple.quarantine /Applications/HourPie.app
```

### Build from source

Requires macOS 13+ and the Xcode command line tools.

```bash
git clone https://github.com/sami3d/HourPie.git
cd HourPie
./build.sh            # or ./build.sh --universal for arm64 + x86_64
cp -R build/HourPie.app /Applications/
open /Applications/HourPie.app
```

## How it works

One Swift file. A one-second `Timer` computes the fraction of the hour remaining, redraws an 18 pt pie wedge with `NSBezierPath`, and sets it as the `NSStatusItem` image. That's the whole app.

## License

[MIT](LICENSE)
