import SwiftUI

struct GitHubTabView: View {
    @State private var isAuthenticated = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isAuthenticated {
                    List {
                        Section("Recent Activity") {
                            ForEach(0..<5) { index in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Sample PR #\(index + 1)")
                                        .font(.headline)
                                    Text("Updated 2 hours ago")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Connect to GitHub")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Sign in to view and manage your pull requests and issues")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Sign in with GitHub") {
                            // Implement GitHub OAuth flow
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("GitHub")
        }
    }
}