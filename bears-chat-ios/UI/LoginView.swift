//
//  LoginView.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import SwiftUI

struct LoginView: View {
    @State var userName = ""
    @FocusState private var isUserNameFocused: Bool
    var onSuccess: ((String) -> Void)?
    
    var body: some View {
        VStack {
            Image(.launchLogo).resizable().frame(width: 400, height: 400)
            HStack {
                Text("Имя:")
                TextField("введите имя", text: $userName)
                    .frame(maxWidth: 200)
                    .focused($isUserNameFocused)
                Button("Далее") {
                    onSuccess?(userName)
                }
                .buttonStyle(.borderedProminent)
                .disabled(userName.isEmpty)
            }
            .padding()
            .background{
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.white))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isUserNameFocused = false
        }
        .gradientBackground()
    }
}

#Preview {
    LoginView()
}
