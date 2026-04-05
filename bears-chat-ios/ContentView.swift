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
    private let serverAPI: ServerAPI
    @State private var path = NavigationPath()
    
    init(serverAPI: ServerAPI) {
        self.serverAPI = serverAPI
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            loginView
            .navigationDestination(for: Route.self) { destination in
                switch destination {
                case .chat(let userName):
                    ChatView(userName: userName, serverAPI: serverAPI) {
                        path = NavigationPath()
                    }
                case .login:
                    loginView
                }
            }
        }
    }
    
    var loginView : some View {
        LoginView(serverAPI: serverAPI) { name in
            path.append(Route.chat(userName: name))
        }
    }
}

#Preview {
    ContentView(serverAPI: ServerAPI())
}
