import SwiftUI

struct AppRootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                Text("聊天")
                    .navigationTitle("聊天")
            }
            .tabItem {
                Label("聊天", systemImage: "message")
            }

            NavigationStack {
                Text("联系人")
                    .navigationTitle("联系人")
            }
            .tabItem {
                Label("联系人", systemImage: "person.2")
            }

            NavigationStack {
                Text("设置")
                    .navigationTitle("设置")
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
        }
    }
}
