import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Calling", systemImage: "phone") {
                Text("Calling")
            }
            Tab("Notes", systemImage: "note.text") {
                Text("Notes")
            }
            Tab("Hobbies", systemImage: "star") {
                Text("Hobbies")
            }
        }
    }
}

#Preview {
    ContentView()
}
