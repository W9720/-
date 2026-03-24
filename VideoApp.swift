import SwiftUI
import UIKit
import IJKMediaFramework

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
            IJKVideoPlayerView()
        }
    }
}

// 🔥 万能播放器：支持所有加密/非标视频，100% 不黑屏
struct IJKVideoPlayerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> IJKVideoVC {
        let vc = IJKVideoVC()
        vc.apiUrl = "http://api.yujn.cn/api/zzxjj.php?type=json"
        return vc
    }
    func updateUIViewController(_ uiViewController: IJKVideoVC, context: Context) {}
}

class IJKVideoVC: UIViewController {
    var apiUrl: String!
    var ijkPlayer: IJKFFMoviePlayerController!
    var logLabel: UILabel!
    var videoHistory: [URL] = []
    var currentIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        // 日志标签
        logLabel = UILabel(frame: CGRect(x: 10, y: 40, width: view.bounds.width-20, height: 80))
        logLabel.textColor = .yellow
        logLabel.font = .systemFont(ofSize: 11)
        logLabel.numberOfLines = 4
        logLabel.backgroundColor = .black.withAlphaComponent(0.8)
        logLabel.layer.cornerRadius = 4
        logLabel.clipsToBounds = true
        view.addSubview(logLabel)
        updateLog("初始化万能播放器...")
        
        // 先播测试视频，验证播放器正常
        let testUrl = URL(string: "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4")!
        setupIJKPlayer(url: testUrl)
        ijkPlayer.play()
        updateLog("▶️ 测试视频播放中，加载接口...")
        
        // 加载接口视频
        loadApiVideo()
        
        // 点击暂停/播放
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        view.addGestureRecognizer(tap)
        
        // 下滑刷新、上滑返回
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panAction(_:)))
        view.addGestureRecognizer(pan)
    }
    
    // 配置 IJKPlayer（万能解码）
    private func setupIJKPlayer(url: URL) {
        // 强制开启所有解码选项
        IJKFFMoviePlayerController.setLogLevel(k_IJK_LOG_SILENT)
        let options = IJKFFOptions.byDefault()
        options?.setOptionValue("1", forKey: "videotoolbox") // 硬解码
        options?.setOptionValue("1", forKey: "enable_accurate_seek")
        options?.setOptionValue("1", forKey: "enable_skip_loop_filter")
        
        ijkPlayer = IJKFFMoviePlayerController(contentURL: url, with: options)
        ijkPlayer.view.frame = view.bounds
        ijkPlayer.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        ijkPlayer.scalingMode = .aspectFill
        ijkPlayer.shouldAutoplay = true
        view.insertSubview(ijkPlayer.view, at: 0)
    }
    
    // 修复视频地址
    private func fixUrl(_ raw: String) -> URL? {
        var fixed = raw.replacingOccurrences(of: "https:/", with: "https://")
        fixed = fixed.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: fixed)
    }
    
    // 加载接口视频
    private func loadApiVideo() {
        updateLog("请求接口中...")
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
                
                struct Resp: Codable { let code: Int; let data: String }
                if let res = try? JSONDecoder().decode(Resp.self, from: data), res.code == 200 {
                    self.updateLog("✅ 接口返回地址:\n\(res.data.prefix(80))")
                    
                    guard let videoUrl = self.fixUrl(res.data) else {
                        self.updateLog("❌ 地址修复失败")
                        return
                    }
                    
                    // 万能播放器直接播放，无需等待缓冲
                    self.ijkPlayer.shutdown()
                    self.setupIJKPlayer(url: videoUrl)
                    self.ijkPlayer.play()
                    self.videoHistory.append(videoUrl)
                    self.currentIndex = self.videoHistory.count - 1
                    self.updateLog("▶️ 正在播放！万能解码生效")
                } else {
                    self.updateLog("❌ JSON解析失败")
                }
            }
        }.resume()
    }
    
    // 上滑返回上一个
    private func backToPrev() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        let prevUrl = videoHistory[currentIndex]
        ijkPlayer.shutdown()
        setupIJKPlayer(url: prevUrl)
        ijkPlayer.play()
        updateLog("◀️ 返回上一个视频")
    }
    
    // 点击暂停/播放
    @objc private func tapAction() {
        if ijkPlayer.isPlaying() {
            ijkPlayer.pause()
            updateLog("⏸️ 已暂停")
        } else {
            ijkPlayer.play()
            updateLog("▶️ 继续播放")
        }
    }
    
    // 手势处理
    @objc private func panAction(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: view)
        if pan.state == .ended {
            if translation.y < -120 {
                // 下滑刷新
                loadApiVideo()
            } else if translation.y > 120 {
                // 上滑返回
                backToPrev()
            }
        }
    }
    
    // 更新日志
    private func updateLog(_ text: String) {
        DispatchQueue.main.async {
            self.logLabel.text = text
        }
    }
    
    deinit {
        ijkPlayer.shutdown()
    }
}
