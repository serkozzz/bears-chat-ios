//
//  ContentView.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import SwiftUI

enum Route: Hashable {
    case login
    case chat(userName: String)
}

struct ContentView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            LoginView() { name in
                path.append(Route.chat(userName: name))
            }
            .navigationDestination(for: Route.self) { destination in
                switch destination {
                case .chat(let userName):
                    ChatView(userName: userName)
                case .login:
                    LoginView()
                }
            }
        }
        
    }
}

#Preview {
    ContentView()
}
