import SwiftUI
import AVKit
import UIKit
import AVFoundation // ✅ 原有：音频会话依赖

// 你的小姐姐专属接口（稳定可访问）
let girlVideoApi = "https://tucdn.wpon.cn/api-girl/index.php?wpon=json"
// ✅ 新增：封面图地址（解决黑屏，和视频风格匹配）
let videoCoverImage = "https://cdn.jsdelivr.net/gh/iosdevdemo/video-resource/girl-cover.jpg"

@main
struct VideoApp: App {
    // ✅ 原有：App启动时强制开启音频会话，绕过系统静音
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

// 欢迎页（原有逻辑完全保留）
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
                Text("@喜爱民谣")
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

// 核心播放页（原有逻辑+性能优化融合）
struct GirlVideoPlayerView: View {
    // ✅ 原有变量：完全保留
    @State private var currentVideoUrl: URL?
    @State private var player: AVPlayer!
    @State private var isLoading = false
    @State private var timeObserver: Any?
    
    // ✅ 新增：性能优化相关变量（不影响原有逻辑）
    @State private var nextPlayerItem: AVPlayerItem?     // 预加载下一个视频
    @State private var showCover = true                  // 显示封面防黑屏
    @State private var coverImage: UIImage?              // 封面图缓存
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // ✅ 新增：封面图（加载时显示，解决黑屏）
            if showCover, let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
            
            // ✅ 原有：视频播放层（保留）
            if let player = player {
                VideoPlayerLayer(player: player)
                    .ignoresSafeArea()
                    .opacity(showCover ? 0 : 1) // 新增：渐变显示防闪屏
            }
            
            // ✅ 原有：加载提示（保留）
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
            
            // ✅ 原有：操作指引（保留）
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
            // ✅ 新增：预加载封面图（解决首次黑屏）
            loadCoverImage()
            // ✅ 原有：初始化加载第一个视频
            loadGirlVideo()
            // ✅ 新增：预加载下一个视频（提前缓存）
            preloadNextVideo()
        }
        .onDisappear {
            // ✅ 原有：移除观察者（保留）
            removePlayerObservers()
            // ✅ 新增：清理预加载资源（优化内存）
            player?.pause()
            nextPlayerItem = nil
        }
        .onTapGesture {
            // ✅ 原有：点击暂停/播放（保留）
            if let player = player {
                player.timeControlStatus == .playing ? player.pause() : player.play()
            }
        }
        .gesture(
            DragGesture()
                .onEnded { gesture in
                    if gesture.translation.height < -100 {
                        // ✅ 新增：优先切换预加载视频（秒开）
                        if let nextItem = nextPlayerItem {
                            switchToPreloadedVideo(nextItem)
                            preloadNextVideo() // 重新预加载下一个
                        } else {
                            // ✅ 原有：无预加载时走原逻辑
                            loadGirlVideo()
                        }
                    }
                }
        )
        // ✅ 新增：禁用动画提升流畅度
        .animation(.none, value: showCover)
    }
    
    // MARK: - 新增：封面图预加载（解决黑屏）
    private func loadCoverImage() {
        guard let url = URL(string: videoCoverImage) else { return }
        // 后台线程加载，不阻塞UI
        DispatchQueue.global(qos: .userInitiated).async {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.coverImage = image
                }
            }
        }
    }
    
    // MARK: - 新增：预加载下一个视频（核心优化）
    private func preloadNextVideo() {
        // 后台线程请求接口，不卡UI
        DispatchQueue.global(qos: .userInitiated).async {
            guard let url = URL(string: girlVideoApi) else { return }
            
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 8
            config.httpAdditionalHeaders = [
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
                "Accept": "application/json"
            ]
            // 新增：启用URL缓存，减少重复请求
            config.urlCache = URLCache(memoryCapacity: 1024*1024*50, diskCapacity: 1024*1024*200, diskPath: "video_cache")
            
            let session = URLSession(configuration: config)
            session.dataTask(with: url) { data, _, err in
                guard let data = data, err == nil else { return }
                
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
                            // 预加载视频，增大缓冲时长（解决卡顿）
                            let playerItem = AVPlayerItem(url: videoUrl)
                            playerItem.preferredForwardBufferDuration = 10 // 缓冲10秒
                            playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
                            
                            DispatchQueue.main.async {
                                self.nextPlayerItem = playerItem
                                // 提前加载视频数据
                                playerItem.loadValuesAsynchronously(forKeys: ["playable"]) {
                                    do {
                                        try playerItem.status.checkIfError()
                                    } catch {
                                        print("预加载失败: \(error)")
                                    }
                                }
                            }
                        }
                    }
                } catch {
                    print("预加载解析错误: \(error)")
                }
            }.resume()
        }
    }
    
    // MARK: - 新增：切换到预加载视频（秒开无等待）
    private func switchToPreloadedVideo(_ item: AVPlayerItem) {
        isLoading = false
        showCover = false // 隐藏封面
        
        // 复用原有逻辑：移除旧观察者
        removePlayerObservers()
        
        // 切换到预加载视频
        player?.replaceCurrentItem(with: item)
        player?.play()
        
        // 复用原有逻辑：设置观察者
        setupPlayerObservers()
        
        // 清空预加载标记
        nextPlayerItem = nil
    }
    
    // MARK: - 原有：音频会话（完全保留）
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("音频会话设置失败: \(error)")
        }
    }
    
    // MARK: - 原有：播放器观察者（完全保留）
    private func setupPlayerObservers() {
        guard let player = player else { return }
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            // ✅ 优化：播放结束优先用预加载视频
            if let nextItem = self.nextPlayerItem {
                self.switchToPreloadedVideo(nextItem)
                self.preloadNextVideo()
            } else {
                self.loadGirlVideo() // 无预加载时走原逻辑
            }
        }
        
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1, preferredTimescale: 1), queue: .main) { time in
            guard let currentItem = player.currentItem else { return }
            let duration = CMTimeGetSeconds(currentItem.duration)
            let currentTime = CMTimeGetSeconds(time)
            
            if duration > 0 && currentTime >= duration - 1 {
                // ✅ 优化：剩余1秒时预加载（兜底）
                if self.nextPlayerItem == nil {
                    self.preloadNextVideo()
                }
                self.loadGirlVideo() // 保留原有逻辑
            }
        }
    }
    
    // MARK: - 原有：移除观察者（完全保留）
    private func removePlayerObservers() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
    }
    
    // MARK: - 原有：接口请求与视频播放（仅新增防黑屏逻辑）
    private func loadGirlVideo() {
        isLoading = true
        showCover = true // 新增：显示封面防黑屏
        
        guard let url = URL(string: girlVideoApi) else {
            isLoading = false
            showCover = false
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
                    self.showCover = false
                    self.playBackupVideo()
                    return
                }
                
                guard let data = data else {
                    self.showCover = false
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
                            self.showCover = false
                            self.playBackupVideo()
                        }
                    } else {
                        self.showCover = false
                        self.playBackupVideo()
                    }
                } catch {
                    print("JSON解析错误: \(error)")
                    self.showCover = false
                    self.playBackupVideo()
                }
            }
        }.resume()
    }
    
    // MARK: - 原有：播放视频（仅新增防黑屏+缓冲优化）
    private func playVideo(with url: URL) {
        // 原有：重置音频会话
        setupAudioSession()
        // 原有：移除旧观察者
        removePlayerObservers()
        
        // 新增：增大缓冲时长（解决卡顿）
        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 10 // 从2秒改为10秒
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        // 新增：异步加载视频属性，避免UI阻塞
        playerItem.loadValuesAsynchronously(forKeys: ["playable"]) {
            DispatchQueue.main.async {
                self.player = AVPlayer(playerItem: playerItem)
                self.player.play()
                
                // 新增：延迟隐藏封面（确保视频渲染完成）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.showCover = false
                }
                
                // 原有：设置观察者
                self.setupPlayerObservers()
            }
        }
    }
    
    // MARK: - 原有：兜底视频（完全保留）
    private func playBackupVideo() {
        let backupUrl = URL(string: "https://cdn.jsdelivr.net/gh/iosdevdemo/video-resource/girl1.mp4")!
        playVideo(with: backupUrl)
    }
}

// 原生播放层（原有逻辑+硬件加速优化）
struct VideoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view.bounds
        playerLayer.videoGravity = .resizeAspectFill
        
        // ✅ 新增：硬件加速配置（提升流畅度）
        playerLayer.shouldRasterize = true
        playerLayer.rasterizationScale = UIScreen.main.scale
        playerLayer.needsDisplayOnBoundsChange = false
        
        view.layer.addSublayer(playerLayer)
        view.layer.displayIfNeeded()
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // ✅ 新增：异步更新图层，避免UI卡顿
        DispatchQueue.main.async {
            if let layer = uiView.layer.sublayers?.first as? AVPlayerLayer {
                layer.player = self.player
            }
        }
    }
}

// ✅ 新增：扩展（检查播放状态，不影响原有逻辑）
extension AVPlayerItem.Status {
    func checkIfError() throws {
        if self == .failed {
            throw NSError(domain: "VideoError", code: -1, userInfo: [NSLocalizedDescriptionKey: "视频加载失败"])
        }
    }
}
