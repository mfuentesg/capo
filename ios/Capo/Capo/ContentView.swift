import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 56))
            Text("Capo")
                .font(.largeTitle.bold())
            Text("Hello from the native app skeleton")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
