import SwiftUI
import AVKit
import UIKit

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
            VStack(spacing:20) {
                Text("欢迎使用").foregroundColor(.white).font(.title)
                Text("By 喜爱民谣").foregroundColor(.gray).font(.title2)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now()+1.5) { show = true }
        }
        .fullScreenCover(isPresented: $show) {
            // 使用UIKit封装的播放器（强制渲染）
            UIKitVideoPlayerView()
        }
    }
}

// 🔥 核心修复：用UIKit原生播放器替代SwiftUI图层（强制渲染）
struct UIKitVideoPlayerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> VideoPlayerVC {
        let vc = VideoPlayerVC()
        vc.apiUrl = "http://api.yujn.cn/api/zzxjj.php?type=json"
        return vc
    }
    
    func updateUIViewController(_ uiViewController: VideoPlayerVC, context: Context) {}
}

// UIKit播放器控制器（100%渲染，无黑屏）
class VideoPlayerVC: UIViewController {
    var apiUrl: String!
    var player: AVPlayer!
    var playerLayer: AVPlayerLayer!
    var playerItem: AVPlayerItem!
    var logLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        // 1. 初始化日志标签
        logLabel = UILabel()
        logLabel.frame = CGRect(x: 10, y: 40, width: view.bounds.width - 20, height: 100)
        logLabel.textColor = .yellow
        logLabel.font = UIFont.systemFont(ofSize: 11)
        logLabel.numberOfLines = 6
        logLabel.backgroundColor = .black.withAlphaComponent(0.8)
        logLabel.layer.cornerRadius = 4
        logLabel.clipsToBounds = true
        view.addSubview(logLabel)
        updateLog("初始化播放器...")
        
        // 2. 初始化测试视频（确保播放器正常）
        let testUrl = URL(string: "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4")!
        player = AVPlayer(url: testUrl)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view.bounds
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = UIColor.black.cgColor
        view.layer.addSublayer(playerLayer)
        
        // 3. 播放测试视频 + 加载接口视频
        player.play()
        updateLog("▶️ 测试视频播放中，加载接口...")
        loadApiVideo()
        
        // 4. 添加点击暂停/播放
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        view.addGestureRecognizer(tap)
        
        // 5. 添加下滑刷新
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panAction(_:)))
        view.addGestureRecognizer(pan)
    }
    
    // 修复视频地址
    private func fixUrl(_ raw: String) -> URL? {
        var fixed = raw.replacingOccurrences(of: "https:/", with: "https://")
        fixed = fixed.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: fixed)
    }
    
    // 加载接口视频
    private func loadApiVideo() {
        updateLog("请求接口: \(apiUrl.prefix(50))")
        guard let url = URL(string: apiUrl) else {
            updateLog("❌ 接口URL无效")
            return
        }
        
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/132.0.0.0 Safari/537.36"]
        let session = URLSession(configuration: config)
        
        session.dataTask(with: url) { [weak self] data, _, err in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let err = err {
                    self.updateLog("❌ 网络错误: \(err.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self.updateLog("❌ 接口返回空")
                    return
                }
                
                // 解析JSON
                struct Resp: Codable { let code: Int; let data: String }
                if let res = try? JSONDecoder().decode(Resp.self, from: data), res.code == 200 {
                    self.updateLog("✅ 接口返回地址:\n\(res.data.prefix(80))")
                    
                    // 修复地址
                    guard let videoUrl = self.fixUrl(res.data) else {
                        self.updateLog("❌ 地址修复失败")
                        return
                    }
                    
                    // 🔥 核心修复：创建带缓冲监听的播放项
                    self.playerItem = AVPlayerItem(url: videoUrl)
                    
                    // 监听缓冲状态（有缓冲才播放）
                    self.playerItem.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
                    self.playerItem.addObserver(self, forKeyPath: "loadedTimeRanges", options: [.new], context: nil)
                    
                    // 替换播放项（不立即播放）
                    self.player.replaceCurrentItem(with: self.playerItem)
                    self.updateLog("✅ 等待视频缓冲...")
                } else {
                    self.updateLog("❌ JSON解析失败")
                }
            }
        }.resume()
    }
    
    // 监听播放器状态（核心！有缓冲才播放）
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let item = object as? AVPlayerItem else { return }
        
        // 监听播放状态
        if keyPath == "status" {
            switch item.status {
            case .readyToPlay:
                updateLog("✅ 视频解码完成，等待缓冲...")
            case .failed:
                updateLog("❌ 视频解码失败: \(item.error?.localizedDescription ?? "未知错误")")
            case .unknown:
                updateLog("⏳ 视频状态未知，加载中...")
            @unknown default: break
            }
        }
        
        // 监听缓冲（有缓冲才播放）
        if keyPath == "loadedTimeRanges" {
            let loadedTimeRanges = item.loadedTimeRanges
            if !loadedTimeRanges.isEmpty {
                // 有缓冲了，强制播放 + 刷新图层
                player.play()
                playerLayer.frame = view.bounds // 强制刷新图层
                view.layer.displayIfNeeded() // 强制渲染
                updateLog("▶️ 正在播放！缓冲完成")
            }
        }
    }
    
    // 点击暂停/播放
    @objc private func tapAction() {
        if player.timeControlStatus == .playing {
            player.pause()
            updateLog("⏸️ 已暂停")
        } else {
            player.play()
            updateLog("▶️ 继续播放")
        }
    }
    
    // 下滑刷新
    @objc private func panAction(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: view)
        if pan.state == .ended && translation.y < -120 {
            updateLog("🔄 下滑刷新视频...")
            loadApiVideo()
        }
    }
    
    // 更新日志
    private func updateLog(_ text: String) {
        DispatchQueue.main.async {
            self.logLabel.text = text
        }
    }
    
    // 释放监听
    deinit {
        playerItem?.removeObserver(self, forKeyPath: "status")
        playerItem?.removeObserver(self, forKeyPath: "loadedTimeRanges")
    }
}
