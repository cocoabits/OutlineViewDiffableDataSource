import AppKit

/// Storyboard is used automatically.
@NSApplicationMain final class AppDelegate: NSObject {

  /// Content view controller.
  private lazy var mainViewController: MainViewController = .init()

  /// Main window with a master-detail interface.
  private lazy var mainWindow: NSWindow = {
    let window = NSWindow(contentViewController: mainViewController)
    window.center()
    window.setFrameAutosaveName("MainWindow")
    return window
  }()
}

// MARK - NSApplicationDelegate

extension AppDelegate: NSApplicationDelegate {

  /// Shows the main window on screen.
  func applicationDidFinishLaunching(_ notification: Notification) {
    mainWindow.makeKeyAndOrderFront(self)
  }

  /// Quit the app when the main window is closed.
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}
