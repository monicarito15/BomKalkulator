import ActivityKit
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        let group = DispatchGroup()
        for activity in Activity<WorkTripActivityAttributes>.activities {
            group.enter()
            Task.detached {
                await activity.end(nil, dismissalPolicy: .immediate)
                group.leave()
            }
        }
        _ = group.wait(timeout: .now() + 2.0)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.content.userInfo["action"] as? String == "openWorkTrip" {
            NotificationCenter.default.post(name: .openWorkTripTab, object: nil)
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let openWorkTripTab = Notification.Name("openWorkTripTab")
}
