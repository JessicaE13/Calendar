//
//  CalendarApp.swift
//  Calendar
//
//  Updated with CloudKit remote notifications support
//

import SwiftUI
import CloudKit

@main
struct CalendarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register for remote notifications
        application.registerForRemoteNotifications()
        return true
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        // Check if this is a CloudKit notification
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            completionHandler(.failed)
            return
        }
        
        // Handle different types of CloudKit notifications
        switch notification.notificationType {
        case .query:
            // Handle query subscription notifications
            // This would trigger a sync in your TaskManager
            DispatchQueue.main.async {
                // Get the shared TaskManager instance and trigger a sync
                // You might want to post a notification or use a shared observable object
                NotificationCenter.default.post(name: .cloudKitDataChanged, object: nil)
            }
            completionHandler(.newData)
            
        case .database:
            // Handle database change notifications
            completionHandler(.newData)
            
        case .readNotification:
            // Handle read notifications
            completionHandler(.noData)
            
        @unknown default:
            completionHandler(.noData)
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Successfully registered for remote notifications")
    }
}

// Extension for notification names
extension Notification.Name {
    static let cloudKitDataChanged = Notification.Name("cloudKitDataChanged")
}

#Preview {
    ContentView()
}
