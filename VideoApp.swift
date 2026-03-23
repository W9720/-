import SwiftUI
import AVKit

@main
struct VideoApp: App {
    var body: some Scene {
        WindowGroup {
            SplashView()
        }
    }
}

// 欢迎界面 By 喜爱民谣
struct SplashView: View {
    @State private var showVideo = false
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("欢迎使用").font(.title).foregroundColor(.white)
                Text("By 喜爱民谣").font(.title).foregroundColor(.gray)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showVideo = true
            }
        }
        .fullScreenCover(isPresented: $showVideo) {
            VideoFeedView()
        }
    }
}

// 主视频列表（上滑返回 + 下滑刷新新视频）
struct VideoFeedView: View {
    @State private var videoHistory: [URL] = []
    @State private var currentIndex = 0
    @State private var player: AVPlayer?
    @State private var isLoading = false
    
    let apiURL = "https://api.yujn.cn/api/zzxjj.php?type=video"
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear { player.play() }
            }
            
            if isLoading {
                ProgressView().tint(.white).scaleEffect(1.5)
            }
        }
        .ignoresSafeArea()
        .gesture(
            DragGesture().onEnded { g in
                if g.translation.height < -150 {
                    loadNewVideo()
                }
                if g.translation.height > 150 {
                    goBack()
                }
            }
        )
        .onTapGesture {
            guard let p = player else { return }
            p.timeControlStatus == .playing ? p.pause() : p.play()
        }
        .onAppear(perform: loadFirstVideo)
        .preferredColorScheme(.dark)
    }
    
    // 首次加载
    private func loadFirstVideo() {
        if videoHistory.isEmpty {
            loadNewVideo()
        }
    }
    
    // 下滑 → 加载新视频
    private func loadNewVideo() {
        isLoading = true
        guard let reqUrl = URL(string: apiURL) else {
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: reqUrl) { data, _, _ in
            DispatchQueue.main.async {
                guard let data = data,
                      let str = String(data: data, encoding: .utf8) else {
                    isLoading = false
                    return
                }
                
                let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let videoUrl = URL(string: clean), !clean.isEmpty else {
                    isLoading = false
                    return
                }
                
                player?.pause()
                player = AVPlayer(url: videoUrl)
                videoHistory.append(videoUrl)
                currentIndex = videoHistory.count - 1
                isLoading = false
                player?.play()
            }
        }.resume()
    }
    
    // 上滑 → 返回上一个视频
    private func goBack() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        player?.pause()
        player = AVPlayer(url: videoHistory[currentIndex])
        player?.play()
    }
}
