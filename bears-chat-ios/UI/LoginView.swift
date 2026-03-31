//
//  LoginView.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import SwiftUI

struct LoginView: View {
    @State var userName = ""
    var onSuccess: ((String) -> Void)?
    
    var body: some View {
        VStack {
            HStack {
                Text("Имя:")
                TextField("введите имя", text: $userName)
                    .frame(maxWidth: 200)
                Button("Далее") {
                    onSuccess?(userName)
                }
                .buttonStyle(.borderedProminent)
                .disabled(userName.isEmpty)
            }
   

        }
    }
}

#Preview {
    LoginView()
}
