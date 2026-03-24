import SwiftUI
import AVKit
import UIKit

// 你的小姐姐专属接口（稳定可访问）
let girlVideoApi = "https://tucdn.wpon.cn/api-girl/index.php?wpon=json"

@main
struct VideoApp: App {
    var body: some Scene {
        WindowGroup {
            SplashView()
        }
    }
}

// 欢迎页（修复颜色兼容性）
struct SplashView: View {
    @State private var showVideo = false
    
    var body: some View {
        ZStack {
            // ✅ 修复：改用全版本兼容的颜色写法，替代systemPink/systemPurple
            LinearGradient(colors: [Color(red: 1.0, green: 0.18, blue: 0.33).opacity(0.9), 
                                   Color(red: 0.55, green: 0.0, blue: 0.55).opacity(0.9)], 
                          startPoint: .top, 
                          endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: "sparkles.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                Text("人终将为年少不可得之物而困其一生")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("By 喜爱民谣")
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showVideo = true
            }
        }
        .fullScreenCover(isPresented: $showVideo) {
            GirlVideoPlayerView()
        }
    }
}

// 核心播放页（无weak self错误）
struct GirlVideoPlayerView: View {
    @State private var currentVideoUrl: URL? // 当前播放的视频链接
    @State private var player: AVPlayer!
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 视频播放层
            if let player = player {
                VideoPlayerLayer(player: player)
                    .ignoresSafeArea()
            }
            
            // 加载提示
            if isLoading {
                VStack {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(2)
                    Text("加载小姐姐视频...")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                        .padding(.top, 10)
                }
            }
            
            // 底部操作指引
            VStack {
                Spacer()
                HStack(spacing: 20) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                    Text("富则入道而润其根 穷则观屏而勤其手")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)
                }
                .padding(.bottom, 20)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear {
            // 初始化加载第一个视频
            loadGirlVideo()
        }
        // 点击暂停/播放
        .onTapGesture {
            if let player = player {
                player.timeControlStatus == .playing ? player.pause() : player.play()
            }
        }
        // 下滑刷新下一个视频
        .gesture(
            DragGesture()
                .onEnded { gesture in
                    if gesture.translation.height < -100 { // 下滑触发
                        loadGirlVideo() // 重新请求接口获取新视频
                    }
                }
        )
    }
    
    // 核心：请求接口并解析视频链接
    private func loadGirlVideo() {
        isLoading = true
        
        guard let url = URL(string: girlVideoApi) else {
            isLoading = false
            playBackupVideo() // 接口异常时播放兜底视频
            return
        }
        
        // 极速请求配置
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
            "Accept": "application/json"
        ]
        let session = URLSession(configuration: config)
        
        // 无weak self，避免值类型错误
        session.dataTask(with: url) { data, _, err in
            DispatchQueue.main.async {
                self.isLoading = false
                
                // 异常处理
                if let err = err {
                    print("接口请求错误：\(err.localizedDescription)")
                    self.playBackupVideo()
                    return
                }
                
                guard let data = data else {
                    self.playBackupVideo()
                    return
                }
                
                // 解析接口返回的JSON
                do {
                    // 定义接口返回结构
                    struct VideoResponse: Codable {
                        let error: Int
                        let result: Int
                        let mp4: String
                    }
                    
                    let response = try JSONDecoder().decode(VideoResponse.self, from: data)
                    
                    // 验证接口返回正常
                    if response.error == 0 && response.result == 200 {
                        // 清理视频链接的转义符（关键！）
                        var cleanUrl = response.mp4
                            .replacingOccurrences(of: "\\/", with: "/") // 替换转义的斜杠
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // 补全HTTPS前缀（如果链接没有的话）
                        if !cleanUrl.hasPrefix("http") {
                            cleanUrl = "https:\(cleanUrl)"
                        }
                        
                        // 验证链接有效性并播放
                        if let videoUrl = URL(string: cleanUrl) {
                            self.currentVideoUrl = videoUrl
                            self.playVideo(with: videoUrl)
                        } else {
                            self.playBackupVideo()
                        }
                    } else {
                        self.playBackupVideo()
                    }
                } catch {
                    print("JSON解析错误：\(error)")
                    self.playBackupVideo()
                }
            }
        }.resume()
    }
    
    // 播放视频（秒级解析）
    private func playVideo(with url: URL) {
        let playerItem = AVPlayerItem(url: url)
        // 预加载配置，秒播无延迟
        playerItem.preferredForwardBufferDuration = 2
        player = AVPlayer(playerItem: playerItem)
        player.play() // 立即播放
    }
    
    // 兜底视频（接口异常时避免黑屏）
    private func playBackupVideo() {
        // 内置稳定的小姐姐视频直链
        let backupUrl = URL(string: "https://cdn.jsdelivr.net/gh/iosdevdemo/video-resource/girl1.mp4")!
        playVideo(with: backupUrl)
    }
}

// 原生播放层（零黑屏）
struct VideoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view.bounds
        playerLayer.videoGravity = .resizeAspectFill // 全屏适配
        view.layer.addSublayer(playerLayer)
        
        // 强制刷新图层，解决渲染延迟
        view.layer.displayIfNeeded()
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            layer.player = player
        }
    }
}
