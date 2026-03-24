import SwiftUI
import AVKit
import UIKit

@main
struct VideoApp: App {
    var body: some Scene {
        WindowGroup {
            SplashView()
        }
    }
}

// 欢迎页 By 喜爱民谣
struct SplashView: View {
    @State private var show = false
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing:20) {
                Text("欢迎使用").foregroundColor(.white).font(.title)
                Text("By 喜爱民谣").foregroundColor(.gray).font(.title2)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now()+1.5) {
                show = true
            }
        }
        .fullScreenCover(isPresented: $show) {
            VideoPlayerView()
        }
    }
}

// 你指定的接口：http://api.yujn.cn/api/zzxjj.php?type=video
struct VideoPlayerView: View {
    @State private var player: AVPlayer = AVPlayer()
    @State private var isLoading = false
    @State private var videoHistory: [URL] = []
    @State private var currentIndex = 0
    
    // 你要的接口
    let apiURL = "http://api.yujn.cn/api/zzxjj.php?type=video"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoUIView(player: player).ignoresSafeArea()
            
            if isLoading {
                ProgressView().tint(.white).scaleEffect(1.8)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear(perform: loadFirstVideo)
        .onTapGesture {
            player.timeControlStatus == .playing ? player.pause() : player.play()
        }
        .gesture(DragGesture().onEnded { value in
            if value.translation.height < -120 {
                loadNewVideo()
            }
            if value.translation.height > 120 {
                backToPrev()
            }
        })
    }
    
    private func loadFirstVideo() {
        if videoHistory.isEmpty {
            loadNewVideo()
        }
    }
    
    // 🔥 突破屏蔽请求
    private func loadNewVideo() {
        isLoading = true
        
        guard let url = URL(string: apiURL) else {
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        // 最强浏览器伪装
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.timeoutInterval = 20
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data,
                      let text = String(data: data, encoding: .utf8) else {
                    isLoading = false
                    return
                }
                
                let cleanLink = text
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: "\r", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard let videoUrl = URL(string: cleanLink), cleanLink.starts(with: "http") else {
                    isLoading = false
                    return
                }
                
                player.replaceCurrentItem(with: AVPlayerItem(url: videoUrl))
                player.play()
                videoHistory.append(videoUrl)
                currentIndex = videoHistory.count - 1
                isLoading = false
            }
        }.resume()
    }
    
    private func backToPrev() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        player.replaceCurrentItem(with: AVPlayerItem(url: videoHistory[currentIndex]))
        player.play()
    }
}

// UIKit 视频内核（绝对不黑屏）
struct VideoUIView: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        let layer = AVPlayerLayer(player: player)
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
