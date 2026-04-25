import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Logo area
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.paprikaPrimary)
                        
                        Text("MealPlanner")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Plan your meals with Paprika")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, Spacing.xxl)
                    .padding(.bottom, Spacing.lg)
                    
                    // Login form
                    VStack(spacing: Spacing.md) {
                        Text("Sign in with your Paprika sync account")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: Spacing.sm) {
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                #if os(iOS)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                #endif
                                .textFieldStyle(.roundedBorder)
                            
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button {
                            Task {
                                await signIn()
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.paprikaPrimary)
                        .controlSize(.large)
                        .disabled(!isFormValid || isLoading)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, Spacing.lg)
                    
                    // Help link
                    Link(destination: URL(string: "https://www.paprikaapp.com/")!) {
                        Text("Need a Paprika account?")
                            .font(.footnote)
                    }
                    .padding(.top, Spacing.md)

                    #if DEBUG
                    // Debug: Show keychain status
                    KeychainDebugView()
                    #endif
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }
    
    private func signIn() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await appState.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
}

#if DEBUG
struct KeychainDebugView: View {
    @State private var status = "Checking..."

    var body: some View {
        VStack(spacing: 4) {
            Text(status)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("KeychainStatus")

            if let error = KeychainService.lastError {
                Text("Error: \(error)")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("KeychainError")
            }
        }
        .onAppear {
            let keychain = KeychainService()
            if keychain.hasStoredCredentials {
                status = "Keychain: Has credentials"
            } else {
                // Try to get each piece and show which is missing
                var missing: [String] = []
                if (try? keychain.getEmail()) == nil { missing.append("email") }
                if (try? keychain.getPassword()) == nil { missing.append("password") }
                if (try? keychain.getToken()) == nil { missing.append("token") }
                status = "Keychain: Empty (missing: \(missing.joined(separator: ", ")))"
            }
        }
    }
}
#endif

#Preview {
    LoginView()
        .environment(AppState())
}
