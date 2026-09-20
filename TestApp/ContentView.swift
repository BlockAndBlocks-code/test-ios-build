import SwiftUI
import SpriteKit

// MARK: - Точка входа

@main
struct TestAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}

// MARK: - Роутинг экранов

struct ContentView: View {
    @State private var screen: Screen = .menu

    enum Screen { case menu, game }

    var body: some View {
        ZStack {
            switch screen {
            case .menu:
                MenuView { screen = .game }
            case .game:
                GameView { screen = .menu }
            }
        }
    }
}

// MARK: - Меню

struct MenuView: View {
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 30) {
                Text("ТАНЧИКИ")
                    .font(.system(size: 64, weight: .heavy))
                    .foregroundColor(.yellow)
                Text("2 игрока · один iPhone")
                    .foregroundColor(.gray)
                Button(action: onStart) {
                    Text("ИГРАТЬ")
                        .font(.title2.bold())
                        .padding(.horizontal, 50)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .foregroundColor(.black)
                        .cornerRadius(14)
                }
            }
        }
    }
}

// MARK: - Игровой экран

struct GameView: View {
    let onExit: () -> Void
    @State private var scene = GameScene()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SpriteView(scene: scene)
                .ignoresSafeArea()
                .onAppear {
                    scene.onGameOver = { winner in
                        // Через 1.2 сек возвращаемся в меню
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            onExit()
                        }
                    }
                }

            // Кнопка "Меню" в углу
            Button(action: onExit) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(16)
            }
        }
    }
}