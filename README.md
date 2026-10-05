# Pejla

Pejla is a small, native IP scanner for macOS. Pick a network, press Scan, and it lists every device it can find: address, name, hardware (MAC) address, manufacturer, open ports and response time. Results can be exported as CSV.

The name is Swedish: *att pejla* means to take a bearing, to find out where something is.

## Download and install (no GitHub knowledge needed)

**[Download Pejla.dmg](https://github.com/UncleDoomVSSP/Pejla/releases/download/latest/Pejla.dmg)**

1. Click the link above. The file `Pejla.dmg` lands in your Downloads folder.
2. Double-click `Pejla.dmg`. A window opens showing **Pejla** and a shortcut to **Applications**.
3. Drag **Pejla** onto **Applications**.
4. Eject the Pejla disk image (click the eject symbol next to it in Finder's sidebar) and delete `Pejla.dmg` if you like.
5. Open **Pejla** from Applications. See **First launch** below for the one-off security step.

If you prefer a plain zip, [Pejla.zip](https://github.com/UncleDoomVSSP/Pejla/releases/download/latest/Pejla.zip) unpacks straight to `Pejla.app`. Both files are rebuilt by the repository's own build every time the code changes, so the links always give the newest version. Checksums are on the [download page](https://github.com/UncleDoomVSSP/Pejla/releases/tag/latest).

Pejla runs on macOS 13 Ventura or newer, on both Apple silicon and Intel Macs.

### First launch

Pejla is not registered with Apple's notarisation service, so the first time you open it macOS will say it cannot check the app for malicious software. This is expected. You only need to do this once.

**macOS 15 Sequoia and newer**

1. Open Pejla from Applications. A message says the app could not be opened. Click **Done**.
2. Open **System Settings**, then **Privacy & Security**.
3. Scroll down to the **Security** section. Next to the message about Pejla, click **Open Anyway**.
4. Confirm, and enter your password or use Touch ID if asked.

**macOS 13 Ventura and 14 Sonoma**

1. In Applications, hold the **Control** key and click **Pejla**, then choose **Open**.
2. In the dialogue that appears, click **Open**.

If you are comfortable with Terminal, this does the same thing in one line:

```
xattr -d com.apple.quarantine /Applications/Pejla.app
```

### Allowing access to the local network

On macOS 15 and newer, the first scan triggers a question from macOS: "Pejla would like to find and connect to devices on your local network". Click **Allow**. If you clicked Don't Allow by mistake, turn it on under **System Settings > Privacy & Security > Local Network**.

## Using Pejla

- **Interface** (top left): the network to scan. Wi-Fi or Ethernet is picked automatically. The range field fills in with that network, for example `192.168.1.0/24`.
- **Range**: edit it to scan something else. These all work:
  - `192.168.1.0/24` (a whole subnet)
  - `192.168.1.1-254` or `192.168.1.1-192.168.1.254` (a dash range)
  - `192.168.1.40` (one address)
- **Scan** starts; the same button becomes **Stop**.
- Click a row to see everything Pejla learned about that device, with buttons to copy the address, open it in a browser, or connect over SSH, Screen Sharing or SMB when the matching port is open.
- Right-click a row for the same actions.
- Type in the search field to filter. Click a column heading to sort.
- **Export** (or File > Export as CSV, Cmd+E) saves the table as a spreadsheet-friendly file.
- **Settings** (Cmd+,) adjusts the probe timeout, whether to check a wider port list, and name lookups.

The coloured dot next to each address means:

- Green: the device answered a TCP probe or advertises Bonjour services.
- Orange: the device answered ARP only, so it exists but accepted no connections. Firewalled phones and smart devices often look like this.
- Blue: this Mac.

A scan of a typical home network (254 addresses) takes about 15 to 30 seconds. Ranges up to 65536 addresses are accepted but take much longer.

## How it finds devices

Pejla does not need administrator rights and sends no raw packets. For each address it tries a short list of TCP ports. A completed connection or a reset both prove something is there. It then reads the system ARP cache, which the probes have populated with the hardware addresses of every device that answered at the link layer, even if every port was closed or filtered. Devices known to be up get a wider port check, a Bonjour listen and a reverse DNS lookup to find names. Manufacturers are looked up from the IEEE OUI registry bundled with the app.

The full design is in [docs/DESIGN.md](docs/DESIGN.md).

## Privacy

Pejla talks only to the addresses you ask it to scan. It makes no connections to the internet, collects nothing and stores nothing except your settings. Scan only networks you own or have permission to scan.

## Building from source

Requirements: macOS 13 or newer with Xcode 15 or newer (or the matching Command Line Tools).

```
git clone https://github.com/UncleDoomVSSP/Pejla.git
cd Pejla
swift test                 # run the unit tests
swift run Pejla            # run straight from the build directory
Scripts/build-app.sh       # build dist/Pejla.app, a .dmg and a .zip
```

`Scripts/build-app.sh` produces a universal binary by default. Set `PEJLA_UNIVERSAL=0` for a quicker native-only build.

## Releasing

Every push runs the Build and test workflow. If the build passes, it uploads `Pejla.dmg` and `Pejla.zip` to the rolling [latest build](https://github.com/UncleDoomVSSP/Pejla/releases/tag/latest) release, which is what the download links above point to.

Numbered releases are separate. Pushing a tag such as `v1.0.0` runs the Release workflow, which builds, tests, packages and publishes a versioned .dmg and .zip on the [releases page](https://github.com/UncleDoomVSSP/Pejla/releases). The workflow can also be started by hand from the Actions tab with a version number.

```
git tag v1.0.0
git push origin v1.0.0
```

## Repository layout

```
Package.swift                 Swift Package Manager manifest
Sources/PejlaCore/            scanning engine, no UI (tested)
Sources/Pejla/                SwiftUI app
Tests/PejlaCoreTests/         unit tests
Packaging/                    Info.plist and the app icon source
Scripts/                      build, icon and vendor-list scripts
.github/workflows/            CI build on every push, release on tags
docs/DESIGN.md                design notes
```
