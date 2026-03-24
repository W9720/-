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

// 欢迎页 By 喜爱民谣
struct SplashView: View {
    @State private var showVideo = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("欢迎使用").font(.title).foregroundColor(.white)
                Text("By 喜爱民谣").foregroundColor(.gray)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showVideo = true
            }
        }
        .fullScreenCover(isPresented: $showVideo) {
            VideoPlayerView()
        }
    }
}

// ✅ 适配你的 JSON 接口（精准解析 data 字段）
struct VideoPlayerView: View {
    @State private var player: AVPlayer = AVPlayer()
    @State private var isLoading = false
    @State private var videoHistory: [URL] = []
    @State private var currentIndex = 0
    
    // 你的 JSON 接口地址
    let api = "http://api.yujn.cn/api/zzxjj.php?type=json"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoLayerView(player: player).ignoresSafeArea()
            
            // 加载动画
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2.0)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear(perform: loadFirstVideo)
        // 点击暂停/播放
        .onTapGesture {
            guard let currentItem = player.currentItem else { return }
            if player.timeControlStatus == .playing {
                player.pause()
            } else {
                player.play()
            }
        }
        // 下滑加载新视频、上滑返回上一个
        .gesture(DragGesture().onEnded { value in
            if value.translation.height < -120 { // 下滑
                loadNewVideo()
            }
            if value.translation.height > 120 { // 上滑
                backToPreviousVideo()
            }
        })
    }
    
    // 首次加载视频
    private func loadFirstVideo() {
        if videoHistory.isEmpty {
            loadNewVideo()
        }
    }
    
    // ✅ 核心：解析你的 JSON 接口（data 字段是视频地址）
    private func loadNewVideo() {
        isLoading = true
        
        // 校验接口地址
        guard let url = URL(string: api) else {
            isLoading = false
            return
        }
        
        // 构建请求（伪装浏览器，避免被拦截）
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        
        // 发起网络请求并解析 JSON
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                
                // 处理网络错误
                if let error = error {
                    print("网络请求错误：\(error.localizedDescription)")
                    return
                }
                
                // 校验返回数据
                guard let data = data else {
                    print("接口返回空数据")
                    return
                }
                
                // 解析 JSON（匹配你的返回格式）
                do {
                    struct VideoResponse: Codable {
                        let code: Int
                        let video_count: String?
                        let title: String?
                        let data: String? // 视频地址字段
                        let tips: String?
                    }
                    
                    let response = try JSONDecoder().decode(VideoResponse.self, from: data)
                    
                    // 校验视频地址
                    guard let videoUrlStr = response.data, 
                          !videoUrlStr.isEmpty,
                          let videoUrl = URL(string: videoUrlStr) else {
                        print("视频地址解析失败")
                        return
                    }
                    
                    // 播放视频
                    player.replaceCurrentItem(with: AVPlayerItem(url: videoUrl))
                    player.play()
                    
                    // 记录播放历史
                    videoHistory.append(videoUrl)
                    currentIndex = videoHistory.count - 1
                    
                } catch {
                    print("JSON 解析错误：\(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    // 返回上一个视频
    private func backToPreviousVideo() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        let prevUrl = videoHistory[currentIndex]
        player.replaceCurrentItem(with: AVPlayerItem(url: prevUrl))
        player.play()
    }
}

// 底层播放层（确保不黑屏、全屏渲染）
struct VideoLayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        // 配置 AVPlayerLayer
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view.bounds
        playerLayer.videoGravity = .resizeAspectFill // 全屏适配
        view.layer.addSublayer(playerLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
