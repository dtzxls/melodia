import SwiftUI

struct AuthView: View {
    @EnvironmentObject var model: AppModel
    @State private var mode: Mode = .login
    @State private var username = ""
    @State private var password = ""
    @State private var error: String?

    enum Mode { case login, register }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                Circle()
                    .fill(Color.melAccent.gradient)
                    .frame(width: 96, height: 96)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.black)
                    )
                    .padding(.bottom, 24)

                Text("Melodia")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.melTextPrimary)

                Text("Sua música, local e offline")
                    .font(.subheadline)
                    .foregroundColor(.melTextSecondary)
                    .padding(.bottom, 40)

                VStack(spacing: 14) {
                    TextField("Usuário", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color.melCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .foregroundColor(.melTextPrimary)

                    SecureField("Senha", text: $password)
                        .padding()
                        .background(Color.melCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .foregroundColor(.melTextPrimary)
                }
                .padding(.horizontal, 24)

                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.top, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                }

                Button {
                    submit()
                } label: {
                    Text(mode == .login ? "Entrar" : "Criar conta")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.melAccent)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Button {
                    withAnimation(.easeInOut) {
                        mode = mode == .login ? .register : .login
                        error = nil
                    }
                } label: {
                    Text(mode == .login ? "Não tem conta? Criar uma" : "Já tem conta? Entrar")
                        .font(.subheadline)
                        .foregroundColor(.melTextSecondary)
                }
                .padding(.top, 12)

                Spacer()
                Spacer()
            }
            .screenBackground()
        }
    }

    private func submit() {
        error = nil
        do {
            if mode == .login {
                try model.login(username: username, password: password)
            } else {
                try model.register(username: username, password: password)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}