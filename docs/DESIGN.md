# Pejla design

## Goals

- A native Mac app that someone can download and run without installing a toolchain, Homebrew or Xcode.
- Find every device on the local subnet quickly, with no administrator password and no kernel extensions.
- Show the information people look for: who is on my network, what is it, what does it expose.
- Keep the whole thing small enough to read in an afternoon.

## Non-goals

- Replacing nmap. Pejla does not do OS fingerprinting, UDP scanning, SYN scanning or scripting.
- Scanning beyond the local network. It works on remote ranges, but only TCP evidence is available there.
- App Store distribution or Apple notarisation. Both need a paid developer account; the project can add them later without changing the code.

## Architecture

Two Swift Package Manager targets:

- `PejlaCore` is a library with no UI dependencies. It holds address maths, interface enumeration, the TCP prober, the ARP reader, Bonjour discovery, reverse DNS, the vendor database, and the scan runner that ties them together. Everything that can be unit tested lives here.
- `Pejla` is the SwiftUI app. It owns the window, the table, the detail panel, settings and CSV export, and talks to the core through one object, `ScanController`.

The scan runs as a detached task and reports back through an `AsyncStream<ScanEvent>`. The controller, on the main actor, consumes the stream and updates published state. Cancelling the consuming task terminates the stream, which cancels the worker. No locks or callbacks cross the UI boundary.

## Scan pipeline

1. **Discovery.** Every target address is probed on a dozen common TCP ports (22, 53, 80, 139, 443, 445, 548, 3389, 5000, 7000, 8080, 62078) using Network.framework connections with a short timeout (1 s by default). A completed handshake means open. A reset means closed, which still proves a host exists. A timeout proves nothing. Up to 32 hosts are in flight at once and a global limiter caps simultaneous sockets at 256.
2. **ARP.** Every probe to a local address makes the kernel send an ARP request. After discovery, `arp -an` is read and parsed. Any target with a complete entry is marked alive and gets its MAC address. This catches phones, smart plugs and anything else that drops unsolicited TCP.
3. **Services.** Hosts known to be alive are probed on a wider list of about fifty ports. Only live hosts pay this cost, so it adds a few seconds, not minutes.
4. **Names.** Bonjour browsing runs for a few seconds across common service types (AirPlay, companion-link, SMB, printers, Chromecast, HomeKit, Matter and so on). Resolved services give device names and a list of advertised services. Reverse DNS through `getnameinfo` then fills in hostnames for anything still unnamed; on macOS the system resolver also answers from multicast DNS.

Manufacturer names come from the first three octets of the MAC address. Release builds bundle the IEEE OUI registry, downloaded at build time; a small built-in table covers the common cases if that download failed. Addresses with the locally administered bit set are shown as "Private address", which is what randomised Wi-Fi addresses look like.

## Why TCP plus ARP instead of ICMP ping

Unprivileged ICMP sockets exist on macOS but are fiddly, and many devices ignore ping anyway. ARP cannot be ignored by anything that wants to talk on the LAN, and TCP connect needs no privileges. The combination finds more devices than ping with less code. The trade-off is that on networks other than the local subnet, only TCP evidence exists.

## User interface

One window: toolbar (interface picker, range field, Scan/Stop, Export, Refresh, search), a sortable table, an optional detail panel for the selected row, and a status bar with progress and a legend. Settings live in the standard Settings window. Menu commands mirror the toolbar so everything is reachable from the keyboard.

The table shows only addresses with evidence of a device. Rows appear as they are found, so a scan feels fast even when it has not finished.

## Distribution

GitHub Actions builds on a macOS runner:

- `ci.yml` runs `swift test` and `Scripts/build-app.sh` on every push and pull request, keeps the .dmg and .zip as a build artefact, and on every push also uploads them under fixed names (`Pejla.dmg`, `Pejla.zip`) to a rolling release tagged `latest`. The README links to those fixed URLs, so a download is always available without anyone cutting a release by hand.
- `release.yml` runs on tags matching `v*` (or by hand with a version number), builds a universal binary, and publishes the .dmg, .zip and SHA-256 checksums as a GitHub Release with install notes in the body.

`Scripts/build-app.sh` assembles the bundle by hand: binary, Info.plist with the version substituted, the icon converted with `sips` and `iconutil`, the vendor registry, then an ad hoc code signature (required to run at all on Apple silicon) and `hdiutil` for the disk image.

Because the app is not notarised, Gatekeeper shows a warning on first launch. The README walks through the two ways round it, which differ between macOS 14 and 15.

## Privacy and permissions

- No sandbox entitlements, because the app runs `/usr/sbin/arp` and opens raw TCP connections to arbitrary local addresses.
- `NSLocalNetworkUsageDescription` is set so macOS 15 shows its Local Network prompt with a clear reason.
- No network access outside the chosen range. No analytics. Settings are the only thing persisted.

## Limitations

- IPv4 only.
- Ranges are capped at 65536 addresses. Larger subnets must be scanned in pieces.
- Hosts that drop TCP and sit behind a router (not on the local link) are invisible.
- Vendor lookup is only as good as the registry snapshot taken when the release was built. Users can drop a newer `oui.csv` in `~/Library/Application Support/Pejla/`.
- Bonjour names are only available for devices that advertise one of the browsed service types.

## Possible next steps

Not planned, listed so they are not forgotten: ICMP echo through unprivileged sockets, IPv6 neighbour discovery, saving and comparing scans to spot new devices, wake-on-LAN, and notarisation once a developer account exists.
