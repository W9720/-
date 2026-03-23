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

// 全屏滑动视频播放器
struct FullScreenVideoView: View {
    @State private var videos: [URL] = []
    @State private var currentIndex = 0
    @State private var players: [AVPlayer] = []
    @State private var isPlaying = true
    @State private var isLoading = true
    
    let apiURL = "https://api.yujn.cn/api/zzxjj.php?type=video"
    
    var body: some View {
        ZStack {
            TabView(selection: $currentIndex) {
                ForEach(0..<videos.count, id: \.self) { index in
                    ZStack {
                        Color.black.ignoresSafeArea()
                        
                        if players.indices.contains(index) {
                            VideoPlayer(player: players[index])
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .ignoresSafeArea()
                        }
                    }
                    .tag(index)
                    .onAppear {
                        if players.indices.contains(index) {
                            players[index].play()
                            isPlaying = true
                        }
                    }
                    .onDisappear {
                        if players.indices.contains(index) {
                            players[index].pause()
                        }
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(.black)
            .ignoresSafeArea()
            
            // 点击暂停/播放
            Color.clear
                .ignoresSafeArea()
                .onTapGesture {
                    togglePlayPause()
                }
            
            // 加载动画
            if isLoading {
                ProgressView("加载视频中...")
                    .foregroundColor(.white)
                    .scaleEffect(1.5)
            }
            
            // 暂停图标
            if !isPlaying && !isLoading {
                Image(systemName: "play.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .onAppear(perform: loadVideos)
        .preferredColorScheme(.dark)
    }
    
    private func togglePlayPause() {
        guard !isLoading, players.indices.contains(currentIndex) else { return }
        isPlaying.toggle()
        isPlaying ? players[currentIndex].play() : players[currentIndex].pause()
    }
    
    private func loadVideos() {
        isLoading = true
        guard let url = URL(string: apiURL) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, err in
            DispatchQueue.main.async {
                isLoading = false
                guard let data = data,
                      let str = String(data: data, encoding: .utf8) else { return }
                
                let cleanLink = str.trimmingCharacters(in: .whitespacesAndNewlines)
                if let videoURL = URL(string: cleanLink) {
                    videos = [videoURL, videoURL, videoURL, videoURL, videoURL]
                    players = videos.map { AVPlayer(url: $0) }
                }
            }
        }.resume()
    }
}
