import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "swift")
                .imageScale(.large)
                .foregroundStyle(.orange)
            Text("Hello, BraiderPanel!")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Edit ContentView.swift in VS Code to start building.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
