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
            Text("By 喜爱民谣").foregroundColor(.white)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now()+1) { show = true }
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
    
    // 调试信息（直接显示在屏幕上）
    @State private var debugRaw = ""
    @State private var debugClean = ""
    
    let api = "https://api.yujn.cn/api/zzxjj.php?type=video"
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            }
            
            // 调试信息悬浮层
            VStack {
                Text("原始返回: \(debugRaw)")
                    .foregroundColor(.red)
                    .font(.system(size: 10))
                Text("清理后: \(debugClean)")
                    .foregroundColor(.green)
                    .font(.system(size: 10))
                Spacer()
            }
            
            if isLoading {
                ProgressView().tint(.white).scaleEffect(1.5)
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: initialLoad)
        .onTapGesture {
            player?.timeControlStatus == .playing ? player?.pause() : player?.play()
        }
        .gesture(DragGesture().onEnded { v in
            if v.translation.height < -100 { loadNewVideo() }
            if v.translation.height > 100 { backPrevVideo() }
        })
    }
    
    private func initialLoad() {
        if videoStack.isEmpty { loadNewVideo() }
    }
    
    private func loadNewVideo() {
        isLoading = true
        guard let url = URL(string: api) else {
            isLoading = false
            return
        }
        
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.5", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: req) { data, resp, err in
            DispatchQueue.main.async {
                guard let data = data, let str = String(data: data, encoding: .utf8) else {
                    debugRaw = "无数据"
                    isLoading = false
                    return
                }
                
                // 显示真实返回
                debugRaw = String(str.prefix(150))
                
                let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
                debugClean = String(clean.prefix(150))
                
                guard let videoUrl = URL(string: clean), clean.hasPrefix("http") else {
                    isLoading = false
                    return
                }
                
                player = AVPlayer(url: videoUrl)
                player?.play()
                videoStack.append(videoUrl)
                currentIndex = videoStack.count-1
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
