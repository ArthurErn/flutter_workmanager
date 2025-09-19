import Flutter
import UIKit
import UserNotifications
import BackgroundTasks

@main
@objc class AppDelegate: FlutterAppDelegate {

  private let backgroundSessionIdentifier = "com.workmanager.background.upload"
  private var backgroundSession: URLSession?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Request notification permissions
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    // Setup background URL session
    setupBackgroundSession()

    // Register background task identifiers
    if #available(iOS 13.0, *) {
      registerBackgroundTasks()
    }

    GeneratedPluginRegistrant.register(with: self)

    // Setup method channel for background uploads
    setupMethodChannel()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupBackgroundSession() {
    let config = URLSessionConfiguration.background(withIdentifier: backgroundSessionIdentifier)
    config.sessionSendsLaunchEvents = true
    config.isDiscretionary = false
    backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }

  @available(iOS 13.0, *)
  private func registerBackgroundTasks() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.workmanager.background.task", using: nil) { task in
      self.handleBackgroundTask(task: task as! BGAppRefreshTask)
    }
  }

  @available(iOS 13.0, *)
  private func handleBackgroundTask(task: BGAppRefreshTask) {
    task.expirationHandler = {
      task.setTaskCompleted(success: false)
    }

    // Simulate background work with notification
    self.sendLocalNotification(title: "Background Task", body: "Executando em background...")

    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      task.setTaskCompleted(success: true)
    }
  }

  private func setupMethodChannel() {
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "background_upload", binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "startBackgroundTask":
        if #available(iOS 13.0, *) {
          self.scheduleBackgroundTask()
        }
        result("Background task scheduled")
      case "startBackgroundUpload":
        if let args = call.arguments as? [String: Any],
           let urlString = args["url"] as? String,
           let filePath = args["filePath"] as? String {
          self.startBackgroundUpload(url: urlString, filePath: filePath)
          result("Upload started")
        } else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @available(iOS 13.0, *)
  private func scheduleBackgroundTask() {
    let request = BGAppRefreshTaskRequest(identifier: "com.workmanager.background.task")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 30)

    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      print("Failed to schedule background task: \(error)")
    }
  }

  private func startBackgroundUpload(url: String, filePath: String) {
    guard let uploadURL = URL(string: url),
          let fileURL = URL(string: filePath) else { return }

    var request = URLRequest(url: uploadURL)
    request.httpMethod = "POST"

    let uploadTask = backgroundSession?.uploadTask(with: request, fromFile: fileURL)
    uploadTask?.resume()
  }

  private func sendLocalNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }
}

// MARK: - URLSessionDelegate
extension AppDelegate: URLSessionDelegate, URLSessionTaskDelegate {

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    sendLocalNotification(title: "Upload Complete", body: "Background upload finished successfully")
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error = error {
      sendLocalNotification(title: "Upload Failed", body: "Error: \(error.localizedDescription)")
    } else {
      sendLocalNotification(title: "Upload Success", body: "Background upload completed")
    }
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    DispatchQueue.main.async {
      if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
         let completionHandler = appDelegate.backgroundSessionCompletionHandler {
        appDelegate.backgroundSessionCompletionHandler = nil
        completionHandler()
      }
    }
  }
}

// MARK: - Background URL Session Completion
extension AppDelegate {
  var backgroundSessionCompletionHandler: (() -> Void)? {
    get { return objc_getAssociatedObject(self, &AssociatedKeys.completionHandler) as? (() -> Void) }
    set { objc_setAssociatedObject(self, &AssociatedKeys.completionHandler, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
  }

  func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
    backgroundSessionCompletionHandler = completionHandler
  }
}

private struct AssociatedKeys {
  static var completionHandler = "completionHandler"
}
