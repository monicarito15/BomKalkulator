import SwiftUI

struct SplashView: View {

    @State private var isActive = false
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0

    var body: some View {
        if isActive {
            MainTabView()
        } else {
            ZStack {
                Color.blue
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Image("SplashIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

                    Text("BomKalkulator")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.spring(duration: 0.6)) {
                        scale = 1.0
                        opacity = 1.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            isActive = true
                        }
                    }
                }
            }
        }
    }
}
