import SwiftUI
import AVKit
import UIKit
import AVFoundation
import Foundation
import Photos

// iOS版本兼容扩展
extension View {
    @ViewBuilder
    func scrollContentBackgroundHidden() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

// MARK: - KVO 时长监听封装类
class DurationObserver: NSObject {
    private let onDurationReady: (Double) -> Void
    
    init(onDurationReady: @escaping (Double) -> Void) {
        self.onDurationReady = onDurationReady
        super.init()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "duration", let playerItem = object as? AVPlayerItem {
            let duration = CMTimeGetSeconds(playerItem.duration)
            if duration.isFinite && duration > 0 {
                DispatchQueue.main.async {
                    self.onDurationReady(duration)
                }
            }
        }
    }
}

// MARK: - 播放历史模型
struct PlayHistoryItem: Codable, Identifiable {
    let id = UUID()
    let videoUrl: String
    let playTime: Date
    let videoName: String
    var playbackPosition: Double = 0.0
    
    enum CodingKeys: String, CodingKey {
        case id, videoUrl, playTime, videoName, playbackPosition
    }
    
    var fileName: String {
        URL(string: videoUrl)?.lastPathComponent ?? "未知视频"
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: playTime)
    }
}

// MARK: - 播放历史管理器
class PlayHistoryManager: ObservableObject {
    static let shared = PlayHistoryManager()
    @Published var historyItems: [PlayHistoryItem] = []
    private let maxHistoryCount = 100
    private let userDefaultsKey = "PlayHistoryItems"
    
    private init() {
        loadHistory()
    }
    
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
    
    func addHistory(videoUrl: String) {
        let existingIndex = historyItems.firstIndex { $0.videoUrl == videoUrl }
        if let index = existingIndex {
            historyItems.remove(at: index)
        }
        
        let item = PlayHistoryItem(
            videoUrl: videoUrl,
            playTime: Date(),
            videoName: URL(string: videoUrl)?.lastPathComponent ?? "未知视频_\(Date().timeIntervalSince1970)",
            playbackPosition: 0.0
        )
        
        historyItems.insert(item, at: 0)
        
        if historyItems.count > maxHistoryCount {
            historyItems.removeLast(historyItems.count - maxHistoryCount)
        }
        
        saveHistory()
    }
    
    func updatePlaybackPosition(videoUrl: String, position: Double) {
        if let index = historyItems.firstIndex(where: { $0.videoUrl == videoUrl }) {
            historyItems[index].playbackPosition = position
            saveHistory()
        }
    }
    
    func deleteHistory(item: PlayHistoryItem) {
        historyItems.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    func clearAllHistory() {
        historyItems.removeAll()
        saveHistory()
    }
}

// MARK: - 主应用入口
@main
struct VideoApp: App {
    @StateObject private var historyManager = PlayHistoryManager.shared
    
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
                .preferredColorScheme(.dark)
                .environmentObject(historyManager)
        }
    }
}

// MARK: - 欢迎界面（高端动画版）
struct SplashView: View {
    @State private var showMain = false
    @State private var animateLogo = false
    @State private var animateText = false
    @EnvironmentObject var historyManager: PlayHistoryManager
    
    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color.black
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 图标 / LOGO
                Image(systemName: "play.rectangle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .pink.opacity(0.5), radius: 20, x: 0, y: 5)
                    .scaleEffect(animateLogo ? 1 : 0.3)
                    .opacity(animateLogo ? 1 : 0)
                
                // 主标题
                Text("别说反话 别冷冰冰")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(animateText ? 1 : 0)
                    .offset(y: animateText ? 0 : 20)
                
                // 副标题
                Text("By 喜爱民谣")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(animateText ? 1 : 0)
                    .offset(y: animateText ? 0 : 20)
            }
        }
        .statusBarHidden()
        .onAppear {
            // 第一段：LOGO动画
            withAnimation(.easeOut(duration: 0.8)) {
                animateLogo = true
            }
            
            // 第二段：文字动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.8)) {
                    animateText = true
                }
            }
            
            // 第三段：退出动画 + 进入主页
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeIn(duration: 0.4)) {
                    animateLogo = false
                    animateText = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showMain = true
                }
            }
        }
        .fullScreenCover(isPresented: $showMain) {
            MainTabView()
                .environmentObject(historyManager)
                .transition(.opacity.combined(with: .scale))
        }
    }
}

// MARK: - 主Tab页
struct MainTabView: View {
    @EnvironmentObject var historyManager: PlayHistoryManager
    
    var body: some View {
        TabView {
            GirlVideoPlayerView()
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
        .environmentObject(historyManager)
    }
}

// MARK: - 下载进度模型
class DownloadTaskModel: ObservableObject {
    @Published var progress: Float = 0.0
    @Published var isDownloading = false
    @Published var isCompleted = false
    var task: URLSessionDownloadTask?
    var videoUrl: URL?
}

// MARK: - 时间格式化工具
func formatTime(_ seconds: Double) -> String {
    let totalSeconds = Int(seconds)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

// MARK: - 核心播放页
struct GirlVideoPlayerView: View {
    @State private var currentVideoUrl: URL?
    @State private var player: AVPlayer!
    @State private var isLoading = false
    @State private var timeObserver: Any?
    
    @State private var nextPlayerItem: AVPlayerItem?
    @State private var showCover = true
    @State private var coverImage: UIImage?
    
    @StateObject private var downloadModel = DownloadTaskModel()
    @State private var showDownloadToast = false
    
    @EnvironmentObject private var historyManager: PlayHistoryManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentTime: Double = 0.0
    @State private var totalDuration: Double = 0.0
    @State private var progress: Double = 0.0
    @State private var isDraggingProgress = false
    
    @State private var durationObserver: DurationObserver?
    
    let girlVideoApi = "https://tucdn.wpon.cn/api-girl/index.php?wpon=json"
    let videoCoverImage = "https://cdn.jsdelivr.net/gh/iosdevdemo/video-resource/girl-cover.jpg"
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if showCover, let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
            
            if let player = player {
                VideoPlayerLayer(player: player)
                    .ignoresSafeArea()
                    .opacity(showCover ? 0 : 1)
            }
            
            if isLoading {
                VStack {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(2)
                    Text("加载视频...")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                        .padding(.top, 10)
                }
            }
            
            VStack {
                Spacer()
                
                VStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(height: 3)
                            .foregroundColor(.white.opacity(0.3))
                            .cornerRadius(1.5)
                        
                        Circle()
                            .frame(width: 8, height: 8)
                            .foregroundColor(.white)
                            .offset(x: CGFloat(progress) * (UIScreen.main.bounds.width - 40) - 4)
                            .opacity(isDraggingProgress || player?.timeControlStatus == .paused ? 1 : 0.7)
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
                .padding(.bottom, 10)
                
                VStack(spacing: 20) {
                    Text("富则入道而润其根 穷则观屏而勤其手")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)
                }
                .padding(.bottom, 100)
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.5), lineWidth: 3)
                            .frame(width: 44, height: 44)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(downloadModel.progress))
                            .stroke(Color.red, lineWidth: 3)
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                            .opacity(downloadModel.isDownloading ? 1 : 0)
                        
                        Image(systemName: downloadModel.isCompleted ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .opacity(downloadModel.isDownloading ? 0.5 : 1)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 120)
                    .onTapGesture {
                        if let url = currentVideoUrl, !downloadModel.isDownloading {
                            startDownload(url: url)
                        }
                    }
                }
            }
            
            if showDownloadToast {
                VStack {
                    Spacer()
                    Text("视频下载完成！前往「我的下载」查看")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 140)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: showDownloadToast)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear {
            if player == nil {
                loadCoverImage()
                loadGirlVideo()
                preloadNextVideo()
            }
        }
        .onDisappear {
            removePlayerObservers()
            player?.pause()
            
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
                        if let url = currentVideoUrl {
                            historyManager.updatePlaybackPosition(videoUrl: url.absoluteString, position: currentTime)
                        }
                        
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
                        
                        if let url = self.currentVideoUrl {
                            self.historyManager.updatePlaybackPosition(videoUrl: url.absoluteString, position: self.currentTime)
                        }
                    }
                }
        )
        .animation(.none, value: showCover)
    }
    
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
    
    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private func showDownloadToast(message: String = "视频下载完成！前往「我的下载」查看") {
        showDownloadToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showDownloadToast = false
        }
    }
    
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
    
    private func preloadNextVideo() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let url = URL(string: self.girlVideoApi) else { return }
            
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
    
    private func switchToPreloadedVideo(_ item: AVPlayerItem) {
        isLoading = false
        showCover = false
        
        removePlayerObservers()
        
        player?.replaceCurrentItem(with: item)
        
        if let url = item.asset as? AVURLAsset {
            let videoUrlString = url.url.absoluteString
            if let historyItem = historyManager.historyItems.first(where: { $0.videoUrl == videoUrlString }) {
                let startTime = CMTime(seconds: historyItem.playbackPosition, preferredTimescale: 1000)
                player?.seek(to: startTime)
            }
            
            historyManager.addHistory(videoUrl: videoUrlString)
            currentVideoUrl = url.url
        }
        
        player?.play()
        
        setupPlayerObservers()
        setupDurationObserver(for: item)
        
        nextPlayerItem = nil
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("音频会话设置失败: \(error)")
        }
    }
    
    private func setupDurationObserver(for playerItem: AVPlayerItem) {
        let observer = DurationObserver { duration in
            self.totalDuration = duration
        }
        self.durationObserver = observer
        playerItem.addObserver(observer, forKeyPath: "duration", options: [.new, .initial], context: nil)
    }
    
    private func setupPlayerObservers() {
        guard let player = player else { return }
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            if let nextItem = self.nextPlayerItem {
                if let url = self.currentVideoUrl {
                    self.historyManager.updatePlaybackPosition(videoUrl: url.absoluteString, position: self.totalDuration)
                }
                
                self.switchToPreloadedVideo(nextItem)
                self.preloadNextVideo()
                
                self.downloadModel.progress = 0
                self.downloadModel.isDownloading = false
                self.downloadModel.isCompleted = false
            } else {
                if let url = self.currentVideoUrl {
                    self.historyManager.updatePlaybackPosition(videoUrl: url.absoluteString, position: self.totalDuration)
                }
                
                self.loadGirlVideo()
            }
        }
        
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1/30, preferredTimescale: 1000), queue: .main) { time in
            guard !self.isDraggingProgress, let currentItem = player.currentItem else { return }
            
            let duration = CMTimeGetSeconds(currentItem.duration)
            let currentTime = CMTimeGetSeconds(time)
            
            if (duration.isFinite && duration > 0) {
                self.currentTime = currentTime
                self.progress = currentTime / duration
                
                if Int(currentTime) % 1 == 0 {
                    if let url = self.currentVideoUrl {
                        self.historyManager.updatePlaybackPosition(videoUrl: url.absoluteString, position: currentTime)
                    }
                }
            }
        }
    }
    
    private func removePlayerObservers() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        if let observer = durationObserver, let currentItem = player?.currentItem {
            currentItem.removeObserver(observer, forKeyPath: "duration")
            self.durationObserver = nil
        }
        
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
        
        currentTime = 0.0
        totalDuration = 0.0
        progress = 0.0
    }
    
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
                        
                        if (!cleanUrl.hasPrefix("http")) {
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
    
    private func playVideo(with url: URL) {
        setupAudioSession()
        removePlayerObservers()
        
        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 10
        
        DispatchQueue.main.async {
            self.player = AVPlayer(playerItem: playerItem)
            
            if let historyItem = self.historyManager.historyItems.first(where: { $0.videoUrl == url.absoluteString }) {
                let startTime = CMTime(seconds: historyItem.playbackPosition, preferredTimescale: 1000)
                self.player?.seek(to: startTime)
            }
            
            self.player.play()
            self.historyManager.addHistory(videoUrl: url.absoluteString)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showCover = false
            }
            
            self.setupDurationObserver(for: playerItem)
            self.setupPlayerObservers()
        }
    }
    
    private func playBackupVideo() {
        let backupUrl = URL(string: "https://cdn.jsdelivr.net/gh/iosdevdemo/video-resource/girl1.mp4")!
        playVideo(with: backupUrl)
    }
}

// MARK: - 下载代理类
class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let downloadModel: DownloadTaskModel
    
    init(downloadModel: DownloadTaskModel) {
        self.downloadModel = downloadModel
        super.init()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            downloadModel.progress = progress
        }
    }
    
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
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error, (error as NSError).code != NSURLErrorCancelled {
            print("下载失败: \(error)")
            downloadModel.isDownloading = false
        }
    }
}

// MARK: - 下载完成通知
extension Notification.Name {
    static let downloadCompleted = Notification.Name("downloadCompleted")
}

// MARK: - 我的下载页面
struct DownloadedVideosView: View {
    @State private var downloadedVideos: [URL] = []
    @State private var selectedVideoUrl: URL?
    @State private var showPlayer = false
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                contentView
            }
        } else {
            NavigationView {
                contentView
            }
            .navigationViewStyle(.stack)
        }
    }
    
    private var contentView: some View {
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
                                saveToAlbum(url: url)
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.white)
                            }
                            
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
                .scrollContentBackgroundHidden()
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
    
    private func loadDownloadedVideos() {
        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let fileUrls = try FileManager.default.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil)
            downloadedVideos = fileUrls.filter { $0.pathExtension.lowercased() == "mp4" }
        } catch {
            print("加载下载列表失败: \(error)")
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
    
    private func saveToAlbum(url: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else { return }
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
            }) { success, error in
                if success {
                    print("保存相册成功")
                }
            }
        }
    }
}

// MARK: - 播放历史页面
struct PlayHistoryView: View {
    @EnvironmentObject private var historyManager: PlayHistoryManager
    @State private var selectedVideoUrl: String?
    @State private var showPlayer = false
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                contentView
            }
        } else {
            NavigationView {
                contentView
            }
            .navigationViewStyle(.stack)
        }
    }
    
    private var contentView: some View {
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
                .scrollContentBackgroundHidden()
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

// MARK: - 历史视频播放页
struct HistoryVideoPlayerView: View {
    let videoUrl: URL
    @State private var player: AVPlayer!
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var historyManager: PlayHistoryManager
    
    @State private var currentTime: Double = 0.0
    @State private var totalDuration: Double = 0.0
    @State private var progress: Double = 0.0
    @State private var isDraggingProgress = false
    @State private var timeObserver: Any?
    
    @State private var durationObserver: DurationObserver?
    @State private var showCover = true
    @State private var coverImage: UIImage?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if showCover, let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
            
            if let player = player {
                VideoPlayerLayer(player: player)
                    .ignoresSafeArea()
                    .opacity(showCover ? 0 : 1)
            }
            
            VStack {
                Spacer()
                
                VStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(height: 3)
                            .foregroundColor(.white.opacity(0.3))
                            .cornerRadius(1.5)
                        
                        Circle()
                            .frame(width: 8, height: 8)
                            .foregroundColor(.white)
                            .offset(x: CGFloat(progress) * (UIScreen.main.bounds.width - 40) - 4)
                            .opacity(isDraggingProgress || player?.timeControlStatus == .paused ? 1 : 0.7)
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
                .padding(.bottom, 10)
            }
            
            VStack {
                HStack {
                    Button {
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
                .padding(.top, 40)
                .padding(.leading, 20)
                
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadCover()
            DispatchQueue.main.async {
                player = AVPlayer(url: videoUrl)
                
                if let historyItem = historyManager.historyItems.first(where: { $0.videoUrl == videoUrl.absoluteString }) {
                    let startTime = CMTime(seconds: historyItem.playbackPosition, preferredTimescale: 1000)
                    player.seek(to: startTime) { _ in
                        self.player.play()
                        self.showCover = false
                    }
                } else {
                    player.play()
                    showCover = false
                }
                
                setupObservers()
            }
        }
        .onDisappear {
            historyManager.updatePlaybackPosition(videoUrl: videoUrl.absoluteString, position: currentTime)
            removeObservers()
            player?.pause()
        }
        .onTapGesture {
            player.timeControlStatus == .playing ? player.pause() : player.play()
        }
    }
    
    private func loadCover() {
        guard let url = URL(string: "https://cdn.jsdelivr.net/gh/iosdevdemo/video-resource/girl-cover.jpg") else { return }
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                DispatchQueue.main.async {
                    coverImage = img
                }
            }
        }
    }
    
    private func setupObservers() {
        let observer = DurationObserver { d in
            totalDuration = d
        }
        durationObserver = observer
        player.currentItem?.addObserver(observer, forKeyPath: "duration", options: .new, context: nil)
        
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1/30, preferredTimescale: 1000), queue: .main) { t in
            currentTime = CMTimeGetSeconds(t)
            if totalDuration > 0 {
                progress = currentTime / totalDuration
            }
        }
    }
    
    private func removeObservers() {
        if let o = timeObserver { player.removeTimeObserver(o) }
        if let o = durationObserver, let item = player.currentItem {
            item.removeObserver(o, forKeyPath: "duration")
        }
    }
}

// MARK: - 离线视频播放页
struct OfflineVideoPlayerView: View {
    let videoUrl: URL
    @State private var player: AVPlayer!
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentTime: Double = 0.0
    @State private var totalDuration: Double = 0.0
    @State private var progress: Double = 0.0
    @State private var isDraggingProgress = false
    @State private var timeObserver: Any?
    @State private var durationObserver: DurationObserver?
    @State private var showCover = true
    @State private var coverImage: UIImage?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if showCover, let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
            
            if let player = player {
                VideoPlayerLayer(player: player)
                    .ignoresSafeArea()
                    .opacity(showCover ? 0 : 1)
            }
            
            VStack {
                Spacer()
                
                VStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(height: 3)
                            .foregroundColor(.white.opacity(0.3))
                            .cornerRadius(1.5)
                        
                        Circle()
                            .frame(width: 8, height: 8)
                            .foregroundColor(.white)
                            .offset(x: CGFloat(progress) * (UIScreen.main.bounds.width - 40) - 4)
                            .opacity(isDraggingProgress || player?.timeControlStatus == .paused ? 1 : 0.7)
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
                .padding(.bottom, 10)
            }
            
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
                .padding(.top, 40)
                .padding(.leading, 20)
                
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadCover()
            DispatchQueue.main.async {
                player = AVPlayer(url: videoUrl)
                player.play()
                showCover = false
                setupObservers()
            }
        }
        .onDisappear {
            removeObservers()
            player?.pause()
        }
        .onTapGesture {
            player.timeControlStatus == .playing ? player.pause() : player.play()
        }
    }
    
    private func loadCover() {
        guard let url = URL(string: "https://cdn.jsdelivr.net/gh/iosdevdemo/video-resource/girl-cover.jpg") else { return }
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                DispatchQueue.main.async {
                    coverImage = img
                }
            }
        }
    }
    
    private func setupObservers() {
        let observer = DurationObserver { d in
            totalDuration = d
        }
        durationObserver = observer
        player.currentItem?.addObserver(observer, forKeyPath: "duration", options: .new, context: nil)
        
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1/30, preferredTimescale: 1000), queue: .main) { t in
            currentTime = CMTimeGetSeconds(t)
            if totalDuration > 0 {
                progress = currentTime / totalDuration
            }
        }
    }
    
    private func removeObservers() {
        if let o = timeObserver { player.removeTimeObserver(o) }
        if let o = durationObserver, let item = player.currentItem {
            item.removeObserver(o, forKeyPath: "duration")
        }
    }
}

// MARK: - 原生播放层
struct VideoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view.bounds
        playerLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(playerLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
