import SwiftUI
import AVKit
import UIKit
import AVFoundation // ✅ 新增：音频会话依赖

// 你的小姐姐专属接口（稳定可访问）
let girlVideoApi = "https://tucdn.wpon.cn/api-girl/index.php?wpon=json"

@main
struct VideoApp: App {
    // ✅ 修复1：App启动时强制开启音频会话，绕过系统静音
    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("音频会话初始化失败: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            SplashView()
        }
    }
}

// 欢迎页
struct SplashView: View {
    @State private var showVideo = false
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 1.0, green: 0.18, blue: 0.33).opacity(0.9), 
                                   Color(red: 0.55, green: 0.0, blue: 0.55).opacity(0.9)], 
                          startPoint: .top, 
                          endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: "sparkles.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                Text("别说反话 别冷冰冰")
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

// 核心播放页（双问题修复：静音有声+自动连播）
struct GirlVideoPlayerView: View {
    @State private var currentVideoUrl: URL?
    @State private var player: AVPlayer!
    @State private var isLoading = false
    // ✅ 新增：监听播放器状态的观察者
    @State private var timeObserver: Any?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                VideoPlayerLayer(player: player)
                    .ignoresSafeArea()
            }
            
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
            
            VStack {
                Spacer()
                HStack(spacing: 20) {
                    
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
        .onDisappear {
            // ✅ 页面消失时移除观察者，避免内存泄漏
            removePlayerObservers()
        }
        .onTapGesture {
            if let player = player {
                player.timeControlStatus == .playing ? player.pause() : player.play()
            }
        }
        .gesture(
            DragGesture()
                .onEnded { gesture in
                    if gesture.translation.height < -100 {
                        loadGirlVideo()
                    }
                }
        )
    }
    
    // MARK: - 音频会话（修复静音无声）
    private func setupAudioSession() {
        do {
            // ✅ 强制设置播放类别，绕过系统静音
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("音频会话设置失败: \(error)")
        }
    }
    
    // MARK: - 播放器观察者（修复自动连播）
    private func setupPlayerObservers() {
        guard let player = player else { return }
        
        // ✅ 监听视频播放结束事件
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            // 视频播完，自动请求下一个视频
            self.loadGirlVideo()
        }
        
        // ✅ 监听播放进度，兜底检测
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1, preferredTimescale: 1), queue: .main) { time in
            guard let currentItem = player.currentItem else { return }
            let duration = CMTimeGetSeconds(currentItem.duration)
            let currentTime = CMTimeGetSeconds(time)
            
            // 视频即将结束（剩余1秒）时，预加载下一个
            if duration > 0 && currentTime >= duration - 1 {
                self.loadGirlVideo()
            }
        }
    }
    
    // ✅ 移除观察者
    private func removePlayerObservers() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
    }
    
    // MARK: - 接口请求与视频播放
    private func loadGirlVideo() {
        isLoading = true
        
        guard let url = URL(string: girlVideoApi) else {
            isLoading = false
            playBackupVideo()
            return
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
            "Accept": "application/json"
        ]
        let session = URLSession(configuration: config)
        
        session.dataTask(with: url) { data, _, err in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let err = err {
                    print("接口请求错误: \(err.localizedDescription)")
                    self.playBackupVideo()
                    return
                }
                
                guard let data = data else {
                    self.playBackupVideo()
                    return
                }
                
                do {
                    struct VideoResponse: Codable {
                        let error: Int
                        let result: Int
                        let mp4: String
                    }
                    
                    let response = try JSONDecoder().decode(VideoResponse.self, from: data)
                    
                    if response.error == 0 && response.result == 200 {
                        var cleanUrl = response.mp4
                            .replacingOccurrences(of: "\\/", with: "/")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if !cleanUrl.hasPrefix("http") {
                            cleanUrl = "https:\(cleanUrl)"
                        }
                        
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
                    print("JSON解析错误: \(error)")
                    self.playBackupVideo()
                }
            }
        }.resume()
    }
    
    private func playVideo(with url: URL) {
        // ✅ 每次播放前重置音频会话，确保静音有声
        setupAudioSession()
        
        // 移除旧观察者
        removePlayerObservers()
        
        // 创建新播放项
        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 2
        
        player = AVPlayer(playerItem: playerItem)
        player.play()
        
        // ✅ 为新播放项添加观察者，实现自动连播
        setupPlayerObservers()
    }
    
    private func playBackupVideo() {
        let backupUrl = URL(string: "https://cdn.jsdelivr.net/gh/iosdevdemo/video-resource/girl1.mp4")!
        playVideo(with: backupUrl)
    }
}

// 原生播放层
struct VideoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view.bounds
        playerLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(playerLayer)
        
        view.layer.displayIfNeeded()
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            layer.player = player
        }
    }
}
