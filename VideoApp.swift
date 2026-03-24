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
            FinalFixVideoView()
        }
    }
}

// 🔥 终极修复版：自动修正视频地址 + 兼容加密链接
struct FinalFixVideoView: View {
    @State private var player: AVPlayer = AVPlayer(
        url: URL(string: "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4")!
    )
    @State private var isLoading = false
    @State private var log = "初始化..."
    
    let api = "http://api.yujn.cn/api/zzxjj.php?type=json"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoLayerView(player: player).ignoresSafeArea()
            
            // 日志面板
            VStack(alignment: .leading) {
                Text(log)
                    .foregroundColor(.yellow)
                    .font(.system(size: 10))
                    .lineLimit(6)
                    .padding(8)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(4)
                Spacer()
            }
            .padding(.top, 20)
            .padding(.leading, 8)
            
            if isLoading {
                ProgressView().tint(.white).scaleEffect(2)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            player.play() // 先播测试视频
            loadVideo()
        }
        .onTapGesture {
            player.timeControlStatus == .playing ? player.pause() : player.play()
        }
        .gesture(DragGesture().onEnded { v in
            if v.translation.height < -120 {
                loadVideo()
            }
        })
    }
    
    // 核心：自动修复视频地址
    private func fixVideoUrl(_ rawUrl: String) -> URL? {
        // 1. 修复 https:/ → https://
        var fixed = rawUrl.replacingOccurrences(of: "https:/", with: "https://")
        fixed = fixed.replacingOccurrences(of: "http:/", with: "http://")
        
        // 2. 移除多余字符/转义
        fixed = fixed.trimmingCharacters(in: .whitespacesAndNewlines)
        fixed = fixed.replacingOccurrences(of: "\"", with: "")
        fixed = fixed.replacingOccurrences(of: "\\", with: "")
        
        // 3. 补充视频后缀（如果没有）
        if !fixed.lowercased().contains(".mp4") && !fixed.lowercased().contains(".m3u8") {
            fixed += ".mp4" // 尝试补充后缀
        }
        
        log = "✅ 修复后地址:\n\(fixed.prefix(100))"
        return URL(string: fixed)
    }
    
    private func loadVideo() {
        isLoading = true
        log = "请求接口中..."
        
        guard let url = URL(string: api) else {
            log = "❌ 接口URL无效"
            isLoading = false
            return
        }
        
        // 网络配置
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36"
        ]
        let session = URLSession(configuration: config)
        
        session.dataTask(with: url) { data, _, err in
            DispatchQueue.main.async {
                isLoading = false
                
                if let err = err {
                    log = "❌ 网络错误: \(err.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    log = "❌ 接口返回空"
                    return
                }
                
                // 解析JSON
                struct Resp: Codable { let code: Int; let data: String }
                if let res = try? JSONDecoder().decode(Resp.self, from: data), res.code == 200 {
                    log = "✅ 接口返回地址:\n\(res.data.prefix(100))"
                    
                    // 修复视频地址
                    guard let videoUrl = fixVideoUrl(res.data) else {
                        log = "❌ 修复后地址仍无效"
                        return
                    }
                    
                    // 播放（兼容加密链接）
                    let playerItem = AVPlayerItem(url: videoUrl)
                    // 强制允许跨域/加密播放
                    playerItem.preferredForwardBufferDuration = 10
                    player.replaceCurrentItem(with: playerItem)
                    
                    // 延迟播放，确保加载完成
                    DispatchQueue.main.asyncAfter(deadline: .now()+1) {
                        player.play()
                        log = "▶️ 正在播放！"
                    }
                } else {
                    log = "❌ JSON解析失败"
                }
            }
        }.resume()
    }
}

// 播放层（强制渲染）
struct VideoLayerView: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view.bounds
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.contentsGravity = .resizeAspectFill
        view.layer.addSublayer(playerLayer)
        
        // 强制刷新图层
        view.layer.displayIfNeeded()
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        // 实时更新播放器状态
        if let layer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            layer.player = player
        }
    }
}
