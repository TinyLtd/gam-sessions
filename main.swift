import Cocoa

// Menu-bar agent: pick a portfolio company -> Terminal shell wired to its GAM
// config (own GAMCFGDIR = own oauth tokens / service account).
// Add/delete companies straight from the menu.

let fm = FileManager.default
let baseDir: String = {
    if let env = ProcessInfo.processInfo.environment["GAM_COMPANIES_DIR"] { return env }
    return (NSHomeDirectory() as NSString).appendingPathComponent(".gam-companies")
}()

// Names map to directory names — keep them shell/AppleScript-safe.
func isValidName(_ s: String) -> Bool {
    // "." and ".." pass the charset but resolve outside baseDir.
    s != "." && s != ".."
        && s.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil
}

func companies() -> [String] {
    guard let items = try? fm.contentsOfDirectory(atPath: baseDir) else { return [] }
    return items.filter { name in
        var isDir: ObjCBool = false
        let p = (baseDir as NSString).appendingPathComponent(name)
        // isValidName here too, not just on create: these names get interpolated
        // into the Terminal command, and a dir made by hand could carry quotes.
        return fm.fileExists(atPath: p, isDirectory: &isDir) && isDir.boolValue
            && !name.hasPrefix(".") && isValidName(name)
    }.sorted()
}

// GAM usually isn't on a login shell's PATH. Find it and prepend its dir.
// Assignment context (`PATH='x':$PATH`) doesn't word-split, so no quotes needed
// around $PATH — which also keeps the string free of the double quotes that
// would terminate the enclosing AppleScript literal.
func gamPathPrefix() -> String {
    let candidates = ["~/bin/gamadv-xtd3", "~/bin/gam7", "~/bin/gam",
                      "/usr/local/bin", "/opt/homebrew/bin"]
    for c in candidates {
        let dir = (c as NSString).expandingTildeInPath
        if fm.isExecutableFile(atPath: (dir as NSString).appendingPathComponent("gam")) {
            return "export PATH='\(dir)':$PATH; "
        }
    }
    return "echo 'Warning: gam not found in the usual places — check your install.'; "
}

func runTerminal(_ shellCmd: String) {
    // Single line: newlines are illegal inside an AppleScript string literal.
    // shellCmd is built from validated names and known paths, so it carries no
    // double quotes or backslashes of its own.
    let script = """
    tell application "Terminal"
        activate
        do script "\(shellCmd)"
    end tell
    """
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    p.arguments = ["-e", script]
    try? p.run()
}

func openSession(_ name: String) {
    let dir = (baseDir as NSString).appendingPathComponent(name)
    runTerminal(gamPathPrefix()
        + "export GAMCFGDIR='\(dir)'; cd '\(dir)'; clear; "
        + "echo 'GAM session: \(name)'; gam info domain 2>/dev/null | head -3 || true")
}

func addCompany() {
    let alert = NSAlert()
    alert.messageText = "Add a company"
    alert.informativeText = "Short name (letters, numbers, - _ .). Creates its GAM config dir and opens a Terminal with the setup commands."
    alert.addButton(withTitle: "Create")
    alert.addButton(withTitle: "Cancel")
    let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
    field.placeholderString = "acme"
    alert.accessoryView = field
    alert.window.initialFirstResponder = field
    NSApp.activate(ignoringOtherApps: true)
    guard alert.runModal() == .alertFirstButtonReturn else { return }

    let name = field.stringValue.trimmingCharacters(in: .whitespaces)
    guard isValidName(name) else {
        let e = NSAlert(); e.messageText = "Invalid name"
        e.informativeText = "Use only letters, numbers, dash, underscore, dot."
        e.runModal(); return
    }
    let dir = (baseDir as NSString).appendingPathComponent(name)
    if fm.fileExists(atPath: dir) {
        let e = NSAlert(); e.messageText = "Already exists"
        e.informativeText = "\(name) is already set up."
        e.runModal(); return
    }
    try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
    // Don't run `gam oauth create` here: it needs client_secrets.json, which only
    // exists after a project step. Both steps are interactive and the project one
    // creates real Google Cloud resources, so print them rather than firing them.
    runTerminal(gamPathPrefix()
        + "export GAMCFGDIR='\(dir)'; cd '\(dir)'; clear; "
        + "echo 'GAM config for \(name): \(dir)'; echo; "
        + "echo 'Run these, in order:'; "
        + "echo '  gam create project        # new GCP project, or:'; "
        + "echo '  gam use project <id>      # reuse an existing one'; "
        + "echo '  gam oauth create          # authorize a super-admin'; echo; "
        // Common failure worth pre-empting: the project step generates the service
        // account key locally and uploads the public half. Orgs that set
        // disableServiceAccountKeyUpload reject it, leaving private_key empty --
        // and every later SA command then dies on PEM MalformedFraming before it
        // can repair itself. Both recoveries are Console-side.
        + "echo 'If the project step reports:'; "
        + "echo '  Constraint constraints/iam.disableServiceAccountKeyUpload violated'; "
        + "echo 'then oauth2service.json has an empty private_key and every'; "
        + "echo 'gam ... serviceaccount command will fail with PEM MalformedFraming.'; "
        + "echo 'gam create sakey cannot fix it -- it authenticates AS the service'; "
        + "echo 'account, so it needs a working key to make one. Two ways out:'; "
        + "echo '  1. Let Google mint the key instead of uploading one:'; "
        + "echo '     Console > IAM and Admin > Service Accounts > pick the SA >'; "
        + "echo '     Keys > Add key > Create new key > JSON, then save it over'; "
        + "echo '     oauth2service.json in this directory.'; "
        + "echo '  2. Or have an org admin scope the constraint off this project:'; "
        + "echo '     Console > IAM and Admin > Organization policies >'; "
        + "echo '     iam.disableServiceAccountKeyUpload > Manage policy >'; "
        + "echo '     add a rule for this project with Enforcement Off.'; "
        + "echo 'If 1 also fails, the blocker is disableServiceAccountKeyCreation'; "
        + "echo 'and only 2 will do. Plain OAuth still works without a key -- you'; "
        + "echo 'lose only gam user <email> ... against Drive/Gmail/Calendar.'; echo; "
        + "echo 'Already have a config dir for this company? Symlink it instead.'")
}

func deleteCompany(_ name: String) {
    let dir = (baseDir as NSString).appendingPathComponent(name)
    let a = NSAlert()
    a.messageText = "Move “\(name)” to the Trash?"
    a.informativeText = "This removes its GAM config, including OAuth tokens. It goes to the Trash, so you can put it back."
    a.alertStyle = .warning
    a.addButton(withTitle: "Move to Trash")
    a.addButton(withTitle: "Cancel")
    NSApp.activate(ignoringOtherApps: true)
    guard a.runModal() == .alertFirstButtonReturn else { return }
    do {
        // Trash, never unlink: this is the user's only copy of those tokens.
        try fm.trashItem(at: URL(fileURLWithPath: dir), resultingItemURL: nil)
    } catch {
        let e = NSAlert(); e.messageText = "Couldn't delete \(name)"
        e.informativeText = error.localizedDescription
        e.runModal()
    }
}

class Delegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ n: Notification) {
        // One icon per machine. Launching again (Finder, `open`, or the
        // LaunchAgent racing a manual start) would otherwise add a second
        // status item with no way to tell them apart. Checked here rather than
        // with LSMultipleInstancesProhibited, which LaunchServices only honours
        // for bundle launches -- the LaunchAgent execs the binary directly.
        if let bid = Bundle.main.bundleIdentifier {
            let me = ProcessInfo.processInfo.processIdentifier
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: bid)
                .filter { $0.processIdentifier != me }
            if !others.isEmpty { exit(0) }
        }
        try? fm.createDirectory(atPath: baseDir, withIntermediateDirectories: true)
        // Without a stored preferred position macOS can park the item under the
        // notch. Seed one into the free gap on first run; the user can ⌘-drag it
        // afterwards and that choice is what persists.
        let posKey = "NSStatusItem Preferred Position GAMSessions"
        if UserDefaults.standard.object(forKey: posKey) == nil {
            UserDefaults.standard.set(400, forKey: posKey)
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "GAMSessions"
        statusItem.isVisible = true
        if let button = statusItem.button {
            let img = Bundle.main.url(forResource: "icon", withExtension: "png")
                .flatMap { NSImage(contentsOf: $0) }
                ?? NSImage(systemSymbolName: "g.circle.fill", accessibilityDescription: "GAM")
            img?.size = NSSize(width: 18, height: 18)
            img?.isTemplate = true // alpha-only: macOS tints for light/dark menu bar
            button.image = img
            // Icon-only: a wide item gets pushed into the notch dead zone on
            // notched displays when the right-hand menu bar area is full.
            button.imagePosition = .imageOnly
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // Rebuild each time it opens so add/delete show up without a restart.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let list = companies()

        if list.isEmpty {
            let empty = NSMenuItem(title: "No companies yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for name in list {
                // One click on the row opens the shell — the common action.
                let item = NSMenuItem(title: name, action: #selector(pick(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = name
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let add = NSMenuItem(title: "Add Company…", action: #selector(add), keyEquivalent: "n")
        add.target = self
        menu.addItem(add)

        // Delete lives in a submenu so the fast path stays one click.
        let del = NSMenuItem(title: "Delete Company", action: nil, keyEquivalent: "")
        let delMenu = NSMenu()
        if list.isEmpty {
            let none = NSMenuItem(title: "Nothing to delete", action: nil, keyEquivalent: "")
            none.isEnabled = false
            delMenu.addItem(none)
        } else {
            for name in list {
                let d = NSMenuItem(title: "\(name)…", action: #selector(remove(_:)), keyEquivalent: "")
                d.target = self
                d.representedObject = name
                delMenu.addItem(d)
            }
        }
        del.submenu = delMenu
        menu.addItem(del)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    // representedObject, not title: submenu titles carry a trailing ellipsis.
    @objc func pick(_ sender: NSMenuItem) {
        if let name = sender.representedObject as? String { openSession(name) }
    }
    @objc func remove(_ sender: NSMenuItem) {
        if let name = sender.representedObject as? String { deleteCompany(name) }
    }
    @objc func add() { addCompany() }
}

// Runnable check for the name guard (the one security-relevant branch):
//   ./GAMSessions.app/Contents/MacOS/GAMSessions --selftest
// precondition, not assert — assert is compiled out under -O.
if CommandLine.arguments.contains("--selftest") {
    for ok in ["acme", "acme-co", "acme_co", "a.b", "A1"] {
        precondition(isValidName(ok), "should accept \(ok)")
    }
    for bad in ["", "a b", "a'; rm -rf ~; echo '", "a\"b", "a$b", "a;b", "a/b", "..", ".", "a\nb"] {
        precondition(!isValidName(bad), "should reject \(bad)")
    }
    precondition(gamPathPrefix().contains("export PATH") || gamPathPrefix().contains("not found"))
    print("selftest ok")
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu-bar only, no Dock icon
let delegate = Delegate()
app.delegate = delegate
app.run()
