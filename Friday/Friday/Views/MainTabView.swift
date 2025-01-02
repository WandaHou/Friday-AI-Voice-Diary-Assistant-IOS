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
            
            NavigationView {
                CacheView()
            }
            .tabItem {
                Image(systemName: "clock.arrow.circlepath")
                Text("Cache")
            }
            .tag(2)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
                .tag(3)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(FridayState.shared)
} 
