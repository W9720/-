import SwiftUI

struct SplashView: View {
    @State private var showVideo = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("欢迎使用")
                    .font(.title)
                    .foregroundColor(.white)
                
                Text("By 喜爱民谣")
                    .font(.title)
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showVideo = true
            }
        }
        .fullScreenCover(isPresented: $showVideo) {
            FullScreenVideoView()
        }
    }
}
