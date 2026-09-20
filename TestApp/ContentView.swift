import SwiftUI

struct ContentView: View {
    @State private var counter = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("Сборка работает! 🎉")
                .font(.title)
            Text("Нажато: \(counter) раз")
            Button("Нажми меня") {
                counter += 1
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}