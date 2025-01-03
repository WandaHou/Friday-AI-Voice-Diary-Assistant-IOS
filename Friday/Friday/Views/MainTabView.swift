import SwiftUI
import UIKit

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FridayView()
                .tabItem {
                    Image(systemName: "waveform")
                    Text("Friday")
                }
                .tag(0)
            
            ForumView()
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("Forum")
                }
                .tag(1)
            
            if #available(iOS 16.0, *) {
                NavigationStack {
                    CacheView()
                }
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Cache")
                }
                .tag(2)
            } else {
                // Fallback on earlier versions
            }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
                .tag(3)
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    MainTabView()
        .environmentObject(FridayState.shared)
} 
