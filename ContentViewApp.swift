import SwiftUI
import FirebaseCore
import UIKit

// 在App運行前設置UI外觀
extension UINavigationBar {
    static func setGlobalAppearance() {
        // 配置導航欄外觀
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = .systemBackground
        
        // 設置返回按鈕圖標顏色為橙色（使用RGB值確保顏色正確）
        UINavigationBar.appearance().tintColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
        
        // 解決雙重返回按鈕的問題 - 完全隱藏返回按鈕標題
        let backButtonAppearance = UIBarButtonItemAppearance()
        backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        backButtonAppearance.highlighted.titleTextAttributes = [.foregroundColor: UIColor.clear]
        backButtonAppearance.disabled.titleTextAttributes = [.foregroundColor: UIColor.clear]
        
        // 應用返回按鈕外觀到全局導航欄外觀
        appearance.backButtonAppearance = backButtonAppearance
        
        // 應用外觀到所有導航欄
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // 強制設置返回按鈕文字為空白
        UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(
            UIOffset(horizontal: -1000, vertical: 0), for: .default)
    }
}

// 首先定義 AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 添加調試信息
        print("正在配置 Firebase...")
        FirebaseApp.configure()
        print("Firebase 配置完成")
        
        // 設置全局導航欄顏色 - 在啟動時設置
        UINavigationBar.setGlobalAppearance()
        
        return true
    }
}

@main
struct ContentViewApp: App {
    // 使用 UIApplicationDelegateAdaptor
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var tabBarManager = TabBarManager()
    
    init() {
        // 在初始化時再次設置，確保優先級更高
        UINavigationBar.setGlobalAppearance()
        
        // 直接使用RGB值設置橙色（橙色在iOS中可能被解釋為不同的顏色）
        UINavigationBar.appearance().tintColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
        
        // 禁用系統自動覆蓋
        UINavigationBar.appearance().isTranslucent = false
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tabBarManager)
                .accentColor(.orange) // 設置整個應用的強調色
                .tint(.orange) // 使用較新的modifier
                .onAppear {
                    // 在視圖出現時再次確保顏色設置
                    UINavigationBar.appearance().tintColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
                }
        }
    }
} 