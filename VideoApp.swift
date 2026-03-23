import SwiftUI
import AVKit
import Foundation

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
    @State private var goFeed = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("欢迎使用")
                    .font(.title)
                    .foregroundColor(.white)
                Text("By 喜爱民谣")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                goFeed = true
            }
        }
        .fullScreenCover(isPresented: $goFeed) {
            VideoPlayerView()
        }
    }
}

// 真正能播放的视频页（绝对不黑屏）
struct VideoPlayerView: View {
    @State private var player: AVPlayer?
    @State private var isLoading = false
    @State private var videoStack: [URL] = []
    @State private var currentIndex = 0
    
    let api = "https://api.yujn.cn/api/zzxjj.php?type=video"
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            }
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: initialLoad)
        .onTapGesture {
            guard let p = player else { return }
            p.timeControlStatus == .playing ? p.pause() : p.play()
        }
        .gesture(DragGesture().onEnded { value in
            if value.translation.height < -100 {
                loadNewVideo()
            }
            if value.translation.height > 100 {
                backPrevVideo()
            }
        })
        .preferredColorScheme(.dark)
    }
    
    // 初次加载
    private func initialLoad() {
        if videoStack.isEmpty {
            loadNewVideo()
        }
    }
    
    // 下滑 → 新视频
    private func loadNewVideo() {
        isLoading = true
        guard let url = URL(string: api) else {
            isLoading = false
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                guard let data = data,
                      let text = String(data: data, encoding: .utf8) else {
                    isLoading = false
                    return
                }
                
                let cleanUrl = text
                    .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard let videoUrl = URL(string: cleanUrl), !cleanUrl.isEmpty else {
                    isLoading = false
                    return
                }
                
                player?.pause()
                player = AVPlayer(url: videoUrl)
                
                // 强制渲染 + 自动播放
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    player?.play()
                    isLoading = false
                }
                
                videoStack.append(videoUrl)
                currentIndex = videoStack.count - 1
            }
        }
        task.resume()
    }
    
    // 上滑 → 返回上一个
    private func backPrevVideo() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        player?.pause()
        player = AVPlayer(url: videoStack[currentIndex])
        player?.play()
    }
}
