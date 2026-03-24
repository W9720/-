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

struct SplashView: View {
    @State private var show = false
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing:20){
                Text("欢迎使用").foregroundColor(.white)
                Text("By 喜爱民谣").foregroundColor(.gray)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now()+1.5) { show = true }
        }
        .fullScreenCover(isPresented: $show) {
            VideoPlayerView()
        }
    }
}

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
                ProgressView().tint(.white).scaleEffect(1.5)
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: initialLoad)
        .onTapGesture {
            guard let p = player else {return}
            p.timeControlStatus == .playing ? p.pause() : p.play()
        }
        .gesture(DragGesture().onEnded { v in
            if v.translation.height < -100 { loadNewVideo() }
            if v.translation.height > 100 { backPrevVideo() }
        })
        .preferredColorScheme(.dark)
    }
    
    private func initialLoad() {
        if videoStack.isEmpty { loadNewVideo() }
    }
    
    // ✅ 核心修复：完全伪装浏览器，绕过服务器拦截
    private func loadNewVideo() {
        isLoading = true
        guard let url = URL(string: api) else {
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        // 🔥 伪装成电脑 Chrome 浏览器（服务器必放行）
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://api.yujn.cn/", forHTTPHeaderField: "Referer")
        
        URLSession.shared.dataTask(with: request) { data, resp, err in
            DispatchQueue.main.async {
                guard let data = data,
                      let str = String(data: data, encoding: .utf8),
                      !str.isEmpty else {
                    isLoading = false
                    return
                }
                
                let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let videoUrl = URL(string: clean), clean.starts(with: "http") else {
                    isLoading = false
                    return
                }
                
                player = AVPlayer(url: videoUrl)
                player?.play()
                videoStack.append(videoUrl)
                currentIndex = videoStack.count - 1
                isLoading = false
            }
        }.resume()
    }
    
    private func backPrevVideo() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        player = AVPlayer(url: videoStack[currentIndex])
        player?.play()
    }
}
