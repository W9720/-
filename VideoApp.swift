import SwiftUI
import AVKit
import UIKit
import AVFoundation
import Foundation // ✅ 修复：用 Foundation 替代 FileManager

// 小姐姐专属接口（稳定可访问）
let girlVideoApi = "https://tucdn.wpon.cn/api-girl/index.php?wpon=json"
// 封面图地址（解决黑屏）
let videoCoverImage = "https://cdn.jsdelivr.net/gh/iosdevdemo/video-resource/girl-cover.jpg"

// ✅ 播放历史模型
struct PlayHistoryItem: Codable, Identifiable {
    let id = UUID()
    let videoUrl: String
    let playTime: Date
    let videoName: String
    var playbackPosition: Double = 0.0 // ✅ 新增：播放进度（秒）
    
    // 计算属性：获取视频文件名
    var fileName: String {
        URL(string: videoUrl)?.lastPathComponent ?? "未知视频"
    }
    
    // 计算属性：格式化播放时间
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: playTime)
    }
}

// ✅ 播放历史管理器（单例）
class PlayHistoryManager: ObservableObject {
    static let shared = PlayHistoryManager()
    @Published var historyItems: [PlayHistoryItem] = []
    private let maxHistoryCount = 100 // 最多保留50条记录
    private let userDefaultsKey = "PlayHistoryItems"
    
    private init() {
        loadHistory()
    }
    
    // 加载历史记录
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                historyItems = try decoder.decode([PlayHistoryItem].self, from: data)
            } catch {
                print("加载播放历史失败: \(error)")
                historyItems = []
            }
        }
    }
    
    // 保存历史记录
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(historyItems)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("保存播放历史失败: \(error)")
        }
    }
    
    // 添加播放记录
    func addHistory(videoUrl: String) {
        // 去重：如果已存在该视频，移除旧记录
        let existingIndex = historyItems.firstIndex { $0.videoUrl == videoUrl }
        if let index = existingIndex {
            historyItems.remove(at: index)
        }
        
        // 创建新记录
        let item = PlayHistoryItem(
            videoUrl: videoUrl,
            playTime: Date(),
            videoName: URL(string: videoUrl)?.lastPathComponent ?? "未知视频_\(Date().timeIntervalSince1970)",
            playbackPosition: 0.0
        )
        
        // 添加到开头
        historyItems.insert(item, at: 0)
        
        // 限制最大数量
        if historyItems.count > maxHistoryCount {
            historyItems.removeLast(historyItems.count - maxHistoryCount)
        }
        
        // 保存
        saveHistory()
    }
    
    // 更新播放进度
    func updatePlaybackPosition(videoUrl: String, position: Double) {
        if let index = historyItems.firstIndex(where: { $0.videoUrl == videoUrl }) {
            historyItems[index].playbackPosition = position
            saveHistory()
        }
    }
    
    // 删除单个记录
    func deleteHistory(item: PlayHistoryItem) {
        historyItems.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    // 清空所有记录
    func clearAllHistory() {
        historyItems.removeAll()
        saveHistory()
    }
}

@main
struct VideoApp: App {
    // 注入历史管理器
    @StateObject private var historyManager = PlayHistoryManager.shared
    
    // App启动时强制开启音频会话，绕过系统静音
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
            // TabView增加播放历史页
            TabView {
                SplashView()
                    .tabItem {
                        Image(systemName: "play.circle.fill")
                        Text("视频播放")
                    }
                
                DownloadedVideosView()
                    .tabItem {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("我的下载")
                    }
                
                PlayHistoryView()
                    .tabItem {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("播放历史")
                    }
            }
            .preferredColorScheme(.dark)
            .environmentObject(historyManager) // 注入历史管理器
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

// 下载进度模型
class DownloadTaskModel: ObservableObject {
    @Published var progress: Float = 0.0
    @Published var isDownloading = false
    @Published var isCompleted = false
    var task: URLSessionDownloadTask?
    var videoUrl: URL?
}

// ✅ 时间格式化工具（新增）
func formatTime(_ seconds: Double) -> String {
    let totalSeconds = Int(seconds)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

// 核心播放页（集成进度条+时长显示）
struct GirlVideoPlayerView: View {
    // 原有变量
    @State private var currentVideoUrl: URL?
    @State private var player: AVPlayer!
    @State private var isLoading = false
    @State private var timeObserver: Any?
    
    // 性能优化相关变量
    @State private var nextPlayerItem: AVPlayerItem?
    @State private var showCover = true
    @State private var coverImage: UIImage?
    
    // 下载功能相关变量
    @StateObject private var downloadModel = DownloadTaskModel()
    @State private var showDownloadToast = false
    
    // 注入历史管理器
    @EnvironmentObject private var historyManager: PlayHistoryManager
    
    // ✅ 新增：进度条相关变量
    @State private var currentTime: Double = 0.0       // 当前播放时间（秒）
    @State private var totalDuration: Double = 0.0     // 视频总时长（秒）
    @State private var progress: Double = 0.0          // 播放进度（0-1）
    @State private var isDraggingProgress = false      // 是否正在拖拽进度条
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 封面图
            if showCover, let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
            
            // 视频播放层
            if let player = player {
                VideoPlayerLayer(player: player)
                    .ignoresSafeArea()
                    .opacity(showCover ? 0 : 1)
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
            
            // ✅ 新增：进度条和时长显示区域
            VStack {
                // 进度条
                VStack(spacing: 8) {
                    // 进度条轨道
                    ZStack(alignment: .leading) {
                        // 背景轨道
                        Rectangle()
                            .frame(height: 3)
                            .foregroundColor(.white.opacity(0.3))
                            .cornerRadius(1.5)
                        
                        // 进度条
                        Rectangle()
                            .frame(width: CGFloat(progress) * UIScreen.main.bounds.width - 40, height: 3)
                            .foregroundColor(.red)
                            .cornerRadius(1.5)
                            .animation(.linear, value: progress)
                        
                        // 进度条拖拽滑块
                        Circle()
                            .frame(width: 8, height: 8)
                            .foregroundColor(.white)
                            .offset(x: CGFloat(progress) * (UIScreen.main.bounds.width - 40) - 4)
                            .opacity(isDraggingProgress || player?.timeControlStatus == .paused ? 1 : 0.7)
                    }
                    .padding(.horizontal, 20)
                    
                    // 时长显示
                    HStack {
                        // 已播放时长
                        Text(formatTime(currentTime))
                            .foregroundColor(.white)
                            .font(.caption)
                        
                        Spacer()
                        
                        // 总时长
                        Text(formatTime(totalDuration))
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 40)
                
                Spacer()
            }
            
            // 下载按钮+进度条
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    // 下载按钮/进度条
                    ZStack {
                        // 进度环
                        Circle()
                            .stroke(Color.gray.opacity(0.5), lineWidth: 3)
                            .frame(width: 44, height: 44)
                        
                        Circle()
                            .trim(from: 0, to: downloadModel.progress)
                            .stroke(Color.red, lineWidth: 3)
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                            .opacity(downloadModel.isDownloading ? 1 : 0)
                        
                        // 下载图标
                        Image(systemName: downloadModel.isCompleted ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .opacity(downloadModel.isDownloading ? 0.5 : 1)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                    .onTapGesture {
                        if let url = currentVideoUrl, !downloadModel.isDownloading {
                            startDownload(url: url)
                        }
                    }
                }
            }
            
            // 操作指引
            VStack {
                Spacer()
                HStack(spacing: 20) {
                    
                    Text("富则入道而润其根 穷则观屏而勤其手")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)
                }
                .padding(.bottom, 70)
            }
            
            // 下载提示 Toast
            if showDownloadToast {
                VStack {
                    Spacer()
                    Text("视频下载完成！前往「我的下载」查看")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 100)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: showDownloadToast)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear {
            loadCoverImage()
            loadGirlVideo()
            preloadNextVideo()
        }
        .onDisappear {
            removePlayerObservers()
            player?.pause()
            nextPlayerItem = nil
            
            // ✅ 保存最后播放进度
            if let url = currentVideoUrl {
                historyManager.updatePlaybackPosition(videoUrl: url.absoluteString, position: currentTime)
            }
            
            downloadModel.task?.cancel()
            downloadModel.isDownloading = false
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
                        // 保存当前进度
                        if let url = currentVideoUrl {
                            historyManager.updatePlaybackPosition(videoUrl: url.absoluteString, position: currentTime)
                        }
                        
                        // 优先切换预加载视频
                        if let nextItem = nextPlayerItem {
                            switchToPreloadedVideo(nextItem)
                            preloadNextVideo()
                            
                            downloadModel.progress = 0
                            downloadModel.isDownloading = false
                            downloadModel.isCompleted = false
                        } else {
                            loadGirlVideo()
                        }
                    }
                }
        )
        // ✅ 新增：进度条拖拽手势
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { gesture in
                    guard totalDuration > 0 else { return }
                    
                    isDraggingProgress = true
                    player?.pause()
                    
                    // 计算拖拽位置对应的进度
                    let xPosition = gesture.location.x
                    let maxWidth = UIScreen.main.bounds.width - 40
                    let newProgress = max(0, min(1, xPosition / maxWidth))
                    
                    progress = newProgress
                    currentTime = newProgress * totalDuration
                }
                .onEnded { _ in
                    guard totalDuration > 0, let player = player else { 
                        isDraggingProgress = false
                        return 
                    }
                    
                    // 跳转到拖拽位置
                    let targetTime = CMTime(seconds: currentTime, preferredTimescale: 1000)
                    player.seek(to: targetTime) { _ in
                        self.isDraggingProgress = false
                        player.play()
                        
                        // 保存进度到历史记录
                        if let url = self.currentVideoUrl {
                            self.historyManager.updatePlaybackPosition(videoUrl: url.absoluteString, position: self.currentTime)
                        }
                    }
                }
        )
        .animation(.none, value: showCover)
    }
    
    // MARK: - 下载功能核心方法
    private func startDownload(url: URL) {
        let fileName = url.lastPathComponent
        let destinationUrl = getDocumentsDirectory().appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destinationUrl.path) {
            downloadModel.isCompleted = true
            showDownloadToast(message: "该视频已下载！")
            return
        }
        
        downloadModel.isDownloading = true
        downloadModel.progress = 0
        downloadModel.videoUrl = url
        
        let session = URLSession(configuration: .default, delegate: DownloadDelegate(downloadModel: downloadModel), delegateQueue: .main)
        let task = session.downloadTask(with: url)
        downloadModel.task = task
        task.resume()
    }
    
    // 获取沙盒Documents目录
    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // 显示下载提示
    private func showDownloadToast(message: String = "视频下载完成！前往「我的下载」查看") {
        showDownloadToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showDownloadToast = false
        }
    }
    
    // 封面图预加载
    private func loadCoverImage() {
        guard let url = URL(string: videoCoverImage) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.coverImage = image
                }
            }
        }
    }
    
    // 预加载下一个视频
    private func preloadNextVideo() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let url = URL(string: girlVideoApi) else { return }
            
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 8
            config.httpAdditionalHeaders = [
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
                "Accept": "application/json"
            ]
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
                            let playerItem = AVPlayerItem(url: videoUrl)
                            playerItem.preferredForwardBufferDuration = 10
                            playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
                            
                            DispatchQueue.main.async {
                                self.nextPlayerItem = playerItem
                            }
                        }
                    }
                } catch {
                    print("预加载解析错误: \(error)")
                }
            }.resume()
        }
    }
    
    // 切换到预加载视频
    private func switchToPreloadedVideo(_ item: AVPlayerItem) {
        isLoading = false
        showCover = false
        
        removePlayerObservers()
        
        player?.replaceCurrentItem(with: item)
        
        // ✅ 恢复历史播放进度
        if let url = item.asset as? AVURLAsset, 
           let videoUrlString = url.url.absoluteString as String?,
           let historyItem = historyManager.historyItems.first(where: { $0.videoUrl == videoUrlString }) {
            
            let startTime = CMTime(seconds: historyItem.playbackPosition, preferredTimescale: 1000)
            player?.seek(to: startTime)
        }
        
        player?.play()
        
        // 记录播放历史
        if let url = item.asset as? AVURLAsset, let videoUrlString = url.url.absoluteString as String? {
            historyManager.addHistory(videoUrl: videoUrlString)
            currentVideoUrl = url.url
        }
        
        // ✅ 监听视频时长和进度
        setupPlayerObservers()
        setupDurationObserver(for: item)
        
        nextPlayerItem = nil
    }
    
    // 音频会话设置
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("音频会话设置失败: \(error)")
        }
    }
    
    // ✅ 新增：监听视频时长
    private func setupDurationObserver(for playerItem: AVPlayerItem) {
        // 监听视频时长加载完成
        playerItem.addObserver(self, forKeyPath: "duration", options: [.new, .initial], context: nil)
        
        // 立即获取时长（如果已加载）
        if playerItem.status == .readyToPlay {
            let duration = CMTimeGetSeconds(playerItem.duration)
            if duration.isFinite && duration > 0 {
                DispatchQueue.main.async {
                    self.totalDuration = duration
                }
            }
        }
    }
    
    // ✅ 重写KVO监听方法
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "duration", let playerItem = object as? AVPlayerItem {
            let duration = CMTimeGetSeconds(playerItem.duration)
            if duration.isFinite && duration > 0 {
                DispatchQueue.main.async {
                    self.totalDuration = duration
                }
            }
        }
    }
    
    // 播放器观察者
    private func setupPlayerObservers() {
        guard let player = player else { return }
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            if let nextItem = self.nextPlayerItem {
                // 保存当前进度
                if let url = self.currentVideoUrl {
                    self.historyManager.updatePlaybackPosition(videoUrl: url.absoluteString, position: self.totalDuration)
                }
                
                self.switchToPreloadedVideo(nextItem)
                self.preloadNextVideo()
                
                self.downloadModel.progress = 0
                self.downloadModel.isDownloading = false
                self.downloadModel.isCompleted = false
            } else {
                // 保存当前进度
                if let url = self.currentVideoUrl {
                    self.historyManager.updatePlaybackPosition(videoUrl: url.absoluteString, position: self.totalDuration)
                }
                
                self.loadGirlVideo()
            }
        }
        
        // ✅ 增强：更精准的进度更新（每秒30次）
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1/30, preferredTimescale: 1000), queue: .main) { [weak self] time in
            guard let self = self, !self.isDraggingProgress, let currentItem = player.currentItem else { return }
            
            let duration = CMTimeGetSeconds(currentItem.duration)
            let currentTime = CMTimeGetSeconds(time)
            
            if duration.isFinite && duration > 0 {
                self.currentTime = currentTime
                self.progress = currentTime / duration
                
                // 实时保存播放进度（每1秒保存一次）
                if Int(currentTime) % 1 == 0 {
                    if let url = self.currentVideoUrl {
                        self.historyManager.updatePlaybackPosition(videoUrl: url.absoluteString, position: currentTime)
                    }
                }
            }
        }
    }
    
    // 移除观察者
    private func removePlayerObservers() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        // ✅ 移除时长监听
        player?.currentItem?.removeObserver(self, forKeyPath: "duration")
        
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
        
        // 重置进度显示
        currentTime = 0.0
        totalDuration = 0.0
        progress = 0.0
    }
    
    // 接口请求与视频播放
    private func loadGirlVideo() {
        isLoading = true
        showCover = true
        
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
                            
                            let fileName = videoUrl.lastPathComponent
                            let destinationUrl = self.getDocumentsDirectory().appendingPathComponent(fileName)
                            self.downloadModel.isCompleted = FileManager.default.fileExists(atPath: destinationUrl.path)
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
    
    // 播放视频
    private func playVideo(with url: URL) {
        setupAudioSession()
        removePlayerObservers()
        
        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 10
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        DispatchQueue.main.async {
            self.player = AVPlayer(playerItem: playerItem)
            
            // ✅ 恢复历史播放进度
            if let historyItem = self.historyManager.historyItems.first(where: { $0.videoUrl == url.absoluteString }) {
                let startTime = CMTime(seconds: historyItem.playbackPosition, preferredTimescale: 1000)
                self.player?.seek(to: startTime)
            }
            
            self.player.play()
            self.historyManager.addHistory(videoUrl: url.absoluteString)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showCover = false
            }
            
            // ✅ 设置时长监听和进度监听
            self.setupDurationObserver(for: playerItem)
            self.setupPlayerObservers()
        }
    }
    
    // 兜底视频
    private func playBackupVideo() {
        let backupUrl = URL(string: "https://cdn.jsdelivr.net/gh/iosdevdemo/video-resource/girl1.mp4")!
        playVideo(with: backupUrl)
    }
}

// 下载代理类
class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let downloadModel: DownloadTaskModel
    
    init(downloadModel: DownloadTaskModel) {
        self.downloadModel = downloadModel
        super.init()
    }
    
    // 监听下载进度
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            downloadModel.progress = progress
        }
    }
    
    // 下载完成
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let videoUrl = downloadModel.videoUrl else { return }
        
        let fileName = videoUrl.lastPathComponent
        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationUrl = documentsUrl.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: destinationUrl.path) {
            try? FileManager.default.removeItem(at: destinationUrl)
        }
        
        do {
            try FileManager.default.moveItem(at: location, to: destinationUrl)
            downloadModel.isCompleted = true
            downloadModel.isDownloading = false
            downloadModel.progress = 1.0
            
            NotificationCenter.default.post(name: .downloadCompleted, object: nil)
        } catch {
            print("保存下载文件失败: \(error)")
            downloadModel.isDownloading = false
        }
    }
    
    // 下载失败
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error, (error as NSError).code != NSURLErrorCancelled {
            print("下载失败: \(error)")
            downloadModel.isDownloading = false
        }
    }
}

// 下载完成通知
extension Notification.Name {
    static let downloadCompleted = Notification.Name("downloadCompleted")
}

// 我的下载页面
struct DownloadedVideosView: View {
    @State private var downloadedVideos: [URL] = []
    @State private var selectedVideoUrl: URL?
    @State private var showPlayer = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if downloadedVideos.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("暂无下载视频")
                            .foregroundColor(.gray.opacity(0.8))
                            .font(.title3)
                        Text("在播放页点击下载按钮保存视频")
                            .foregroundColor(.gray.opacity(0.6))
                            .font(.caption)
                    }
                } else {
                    List {
                        ForEach(downloadedVideos, id: \.self) { url in
                            HStack {
                                Image(systemName: "film")
                                    .foregroundColor(.red)
                                    .padding(.trailing, 10)
                                
                                VStack(alignment: .leading) {
                                    Text(url.lastPathComponent)
                                        .foregroundColor(.white)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    
                                    Text(getFileSize(url: url))
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                
                                Spacer()
                                
                                Button {
                                    deleteVideo(url: url)
                                } label: {
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.red)
                                }
                            }
                            .onTapGesture {
                                selectedVideoUrl = url
                                showPlayer = true
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.black)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("我的下载")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {
                    deleteAllVideos()
                } label: {
                    Text("清空全部")
                        .foregroundColor(.red)
                }
                .disabled(downloadedVideos.isEmpty)
            }
            .onAppear {
                loadDownloadedVideos()
            }
            .onReceive(NotificationCenter.default.publisher(for: .downloadCompleted)) { _ in
                loadDownloadedVideos()
            }
            .fullScreenCover(isPresented: $showPlayer) {
                if let url = selectedVideoUrl {
                    OfflineVideoPlayerView(videoUrl: url)
                }
            }
        }
    }
    
    private func loadDownloadedVideos() {
        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let fileUrls = try FileManager.default.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil)
            downloadedVideos = fileUrls.filter { $0.pathExtension.lowercased() == "mp4" }
        } catch {
            print("加载下载列表失败: \(error)")
            downloadedVideos = []
        }
    }
    
    private func deleteVideo(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            loadDownloadedVideos()
        } catch {
            print("删除视频失败: \(error)")
        }
    }
    
    private func deleteAllVideos() {
        for url in downloadedVideos {
            try? FileManager.default.removeItem(at: url)
        }
        loadDownloadedVideos()
    }
    
    private func getFileSize(url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attributes[.size] as! Int64
            let sizeMB = Double(size) / 1024 / 1024
            return String(format: "%.2f MB", sizeMB)
        } catch {
            return "未知大小"
        }
    }
}

// 播放历史页面
struct PlayHistoryView: View {
    @EnvironmentObject private var historyManager: PlayHistoryManager
    @State private var selectedVideoUrl: String?
    @State private var showPlayer = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if historyManager.historyItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("暂无播放历史")
                            .foregroundColor(.gray.opacity(0.8))
                            .font(.title3)
                        Text("播放视频后会自动保存历史记录")
                            .foregroundColor(.gray.opacity(0.6))
                            .font(.caption)
                    }
                } else {
                    List {
                        ForEach(historyManager.historyItems) { item in
                            HStack {
                                Image(systemName: "play.rectangle")
                                    .foregroundColor(.red)
                                    .padding(.trailing, 10)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.fileName)
                                        .foregroundColor(.white)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    
                                    HStack {
                                        Text("播放时间：\(item.formattedTime)")
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                        
                                        Spacer()
                                        
                                        // ✅ 显示上次播放进度
                                        Text("进度：\(formatTime(item.playbackPosition))")
                                            .foregroundColor(.red.opacity(0.8))
                                            .font(.caption2)
                                    }
                                }
                                
                                Spacer()
                                
                                Button {
                                    historyManager.deleteHistory(item: item)
                                } label: {
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 16))
                                }
                            }
                            .padding(.vertical, 8)
                            .onTapGesture {
                                selectedVideoUrl = item.videoUrl
                                showPlayer = true
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.black)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("播放历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {
                    historyManager.clearAllHistory()
                } label: {
                    Text("清空全部")
                        .foregroundColor(.red)
                }
                .disabled(historyManager.historyItems.isEmpty)
            }
            .fullScreenCover(isPresented: $showPlayer) {
                if let urlString = selectedVideoUrl, let url = URL(string: urlString) {
                    HistoryVideoPlayerView(videoUrl: url)
                }
            }
        }
    }
}

// ✅ 历史视频播放页（升级进度条功能）
struct HistoryVideoPlayerView: View {
    let videoUrl: URL
    @State private var player: AVPlayer!
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var historyManager: PlayHistoryManager
    
    // ✅ 进度条相关变量
    @State private var currentTime: Double = 0.0
    @State private var totalDuration: Double = 0.0
    @State private var progress: Double = 0.0
    @State private var isDraggingProgress = false
    @State private var timeObserver: Any?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                VideoPlayerLayer(player: player)
                    .ignoresSafeArea()
            }
            
            // ✅ 进度条和时长显示
            VStack {
                // 进度条区域
                VStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(height: 3)
                            .foregroundColor(.white.opacity(0.3))
                            .cornerRadius(1.5)
                        
                        Rectangle()
                            .frame(width: CGFloat(progress) * UIScreen.main.bounds.width - 40, height: 3)
                            .foregroundColor(.red)
                            .cornerRadius(1.5)
                            .animation(.linear, value: progress)
                        
                        Circle()
                            .frame(width: 8, height: 8)
                            .foregroundColor(.white)
                            .offset(x: CGFloat(progress) * (UIScreen.main.bounds.width - 40) - 4)
                            .opacity(isDraggingProgress || player.timeControlStatus == .paused ? 1 : 0.7)
                    }
                    .padding(.horizontal, 20)
                    
                    HStack {
                        Text(formatTime(currentTime))
                            .foregroundColor(.white)
                            .font(.caption)
                        
                        Spacer()
                        
                        Text(formatTime(totalDuration))
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 40)
                
                Spacer()
            }
            
            // 返回按钮
            VStack {
                HStack {
                    Button {
                        // 保存进度
                        historyManager.updatePlaybackPosition(videoUrl: videoUrl.absoluteString, position: currentTime)
                        player?.pause()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .padding(16)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(24)
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 40)
            .padding(.leading, 20)
            
            // 暂停/播放按钮
            VStack {
                Spacer()
                Image(systemName: player?.timeControlStatus == .playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(0.7)
                Spacer()
            }
        }
        .onAppear {
            // 初始化播放器
            player = AVPlayer(url: videoUrl)
            
            // 恢复历史播放进度
            if let historyItem = historyManager.historyItems.first(where: { $0.videoUrl == videoUrl.absoluteString }) {
                let startTime = CMTime(seconds: historyItem.playbackPosition, preferredTimescale: 1000)
                player.seek(to: startTime) { _ in
                    self.player.play()
                }
            } else {
                player.play()
            }
            
            // 设置音频会话
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("音频激活失败: \(error)")
            }
            
            // 监听视频时长
            if let currentItem = player.currentItem {
                currentItem.addObserver(self, forKeyPath: "duration", options: [.new, .initial], context: nil)
                
                // 监听播放进度
                timeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1/30, preferredTimescale: 1000), queue: .main) { [weak self] time in
                    guard let self = self, !self.isDraggingProgress, let currentItem = player.currentItem else { return }
                    
                    let duration = CMTimeGetSeconds(currentItem.duration)
                    let currentTime = CMTimeGetSeconds(time)
                    
                    if duration.isFinite && duration > 0 {
                        self.currentTime = currentTime
                        self.progress = currentTime / duration
                        
                        // 实时保存进度
                        if Int(currentTime) % 1 == 0 {
                            self.historyManager.updatePlaybackPosition(videoUrl: self.videoUrl.absoluteString, position: currentTime)
                        }
                    }
                }
            }
        }
        .onDisappear {
            // 保存最后进度
            historyManager.updatePlaybackPosition(videoUrl: videoUrl.absoluteString, position: currentTime)
            
            // 清理资源
            player?.pause()
            if let currentItem = player?.currentItem {
                currentItem.removeObserver(self, forKeyPath: "duration")
            }
            if let observer = timeObserver, let player = player {
                player.removeTimeObserver(observer)
            }
        }
        .onTapGesture {
            if let player = player {
                player.timeControlStatus == .playing ? player.pause() : player.play()
            }
        }
        // 进度条拖拽手势
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { gesture in
                    guard totalDuration > 0 else { return }
                    
                    isDraggingProgress = true
                    player?.pause()
                    
                    let xPosition = gesture.location.x
                    let maxWidth = UIScreen.main.bounds.width - 40
                    let newProgress = max(0, min(1, xPosition / maxWidth))
                    
                    progress = newProgress
                    currentTime = newProgress * totalDuration
                }
                .onEnded { _ in
                    guard totalDuration > 0, let player = player else { 
                        isDraggingProgress = false
                        return 
                    }
                    
                    let targetTime = CMTime(seconds: currentTime, preferredTimescale: 1000)
                    player.seek(to: targetTime) { _ in
                        self.isDraggingProgress = false
                        player.play()
                        self.historyManager.updatePlaybackPosition(videoUrl: self.videoUrl.absoluteString, position: self.currentTime)
                    }
                }
        )
        .preferredColorScheme(.dark)
    }
    
    // KVO监听时长
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "duration", let playerItem = object as? AVPlayerItem {
            let duration = CMTimeGetSeconds(playerItem.duration)
            if duration.isFinite && duration > 0 {
                DispatchQueue.main.async {
                    self.totalDuration = duration
                }
            }
        }
    }
}

// ✅ 离线视频播放页（升级进度条功能）
struct OfflineVideoPlayerView: View {
    let videoUrl: URL
    @State private var player: AVPlayer!
    @Environment(\.dismiss) private var dismiss
    
    // 进度条相关变量
    @State private var currentTime: Double = 0.0
    @State private var totalDuration: Double = 0.0
    @State private var progress: Double = 0.0
    @State private var isDraggingProgress = false
    @State private var timeObserver: Any?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                VideoPlayerLayer(player: player)
                    .ignoresSafeArea()
            }
            
            // 进度条和时长显示
            VStack {
                VStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(height: 3)
                            .foregroundColor(.white.opacity(0.3))
                            .cornerRadius(1.5)
                        
                        Rectangle()
                            .frame(width: CGFloat(progress) * UIScreen.main.bounds.width - 40, height: 3)
                            .foregroundColor(.red)
                            .cornerRadius(1.5)
                            .animation(.linear, value: progress)
                        
                        Circle()
                            .frame(width: 8, height: 8)
                            .foregroundColor(.white)
                            .offset(x: CGFloat(progress) * (UIScreen.main.bounds.width - 40) - 4)
                            .opacity(isDraggingProgress || player.timeControlStatus == .paused ? 1 : 0.7)
                    }
                    .padding(.horizontal, 20)
                    
                    HStack {
                        Text(formatTime(currentTime))
                            .foregroundColor(.white)
                            .font(.caption)
                        
                        Spacer()
                        
                        Text(formatTime(totalDuration))
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 40)
                
                Spacer()
            }
            
            // 返回按钮
            VStack {
                HStack {
                    Button {
                        player?.pause()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .padding(16)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(24)
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 40)
            .padding(.leading, 20)
            
            // 暂停/播放按钮
            VStack {
                Spacer()
                Image(systemName: player?.timeControlStatus == .playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(0.7)
                Spacer()
            }
        }
        .onAppear {
            player = AVPlayer(url: videoUrl)
            player.play()
            
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("音频激活失败: \(error)")
            }
            
            // 监听时长和进度
            if let currentItem = player.currentItem {
                currentItem.addObserver(self, forKeyPath: "duration", options: [.new, .initial], context: nil)
                
                timeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1/30, preferredTimescale: 1000), queue: .main) { [weak self] time in
                    guard let self = self, !self.isDraggingProgress, let currentItem = player.currentItem else { return }
                    
                    let duration = CMTimeGetSeconds(currentItem.duration)
                    let currentTime = CMTimeGetSeconds(time)
                    
                    if duration.isFinite && duration > 0 {
                        self.currentTime = currentTime
                        self.progress = currentTime / duration
                    }
                }
            }
        }
        .onDisappear {
            player?.pause()
            if let currentItem = player?.currentItem {
                currentItem.removeObserver(self, forKeyPath: "duration")
            }
            if let observer = timeObserver, let player = player {
                player.removeTimeObserver(observer)
            }
        }
        .onTapGesture {
            if let player = player {
                player.timeControlStatus == .playing ? player.pause() : player.play()
            }
        }
        // 进度条拖拽
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { gesture in
                    guard totalDuration > 0 else { return }
                    
                    isDraggingProgress = true
                    player?.pause()
                    
                    let xPosition = gesture.location.x
                    let maxWidth = UIScreen.main.bounds.width - 40
                    let newProgress = max(0, min(1, xPosition / maxWidth))
                    
                    progress = newProgress
                    currentTime = newProgress * totalDuration
                }
                .onEnded { _ in
                    guard totalDuration > 0, let player = player else { 
                        isDraggingProgress = false
                        return 
                    }
                    
                    let targetTime = CMTime(seconds: currentTime, preferredTimescale: 1000)
                    player.seek(to: targetTime) { _ in
                        self.isDraggingProgress = false
                        player.play()
                    }
                }
        )
        .preferredColorScheme(.dark)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "duration", let playerItem = object as? AVPlayerItem {
            let duration = CMTimeGetSeconds(playerItem.duration)
            if duration.isFinite && duration > 0 {
                DispatchQueue.main.async {
                    self.totalDuration = duration
                }
            }
        }
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
        
        playerLayer.shouldRasterize = true
        playerLayer.rasterizationScale = UIScreen.main.scale
        playerLayer.needsDisplayOnBoundsChange = false
        
        view.layer.addSublayer(playerLayer)
        view.layer.displayIfNeeded()
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let layer = uiView.layer.sublayers?.first as? AVPlayerLayer {
                layer.player = self.player
            }
        }
    }
}
