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
                            .foregroundStyle(.paprikaPrimary)
                        
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
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
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
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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

#Preview {
    LoginView()
        .environment(AppState())
}
