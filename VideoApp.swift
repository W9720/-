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

// 欢迎界面 By 喜爱民谣
struct SplashView: View {
    @State private var showVideo = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("欢迎使用")
                    .font(.title)
                    .foregroundColor(.white)
                Text("By 喜爱民谣")
                    .font(.title)
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showVideo = true
            }
        }
        .fullScreenCover(isPresented: $showVideo) {
            FullScreenVideoView()
        }
    }
}

// 🔥 修复网络失败 + 强制播放视频
struct FullScreenVideoView: View {
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMsg = ""
    
    // 你的真实视频接口
    let apiUrl = "https://api.yujn.cn/api/zzxjj.php?type=video"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView().tint(.white).scaleEffect(1.5)
                    Text("加载视频中...").foregroundColor(.white)
                }
            } else if !errorMsg.isEmpty {
                Text(errorMsg)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .onTapGesture {
                        loadVideo() // 失败可点击重试
                    }
            } else if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        player.timeControlStatus == .playing ? player.pause() : player.play()
                    }
                    .onAppear {
                        player.play()
                    }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: loadVideo)
    }
    
    private func loadVideo() {
        isLoading = true
        errorMsg = ""
        
        var request = URLRequest(url: URL(string: apiUrl)!)
        request.timeoutInterval = 15
        
        // 修复：允许任意请求 + 超时 + 重试机制
        URLSession.shared.dataTask(with: request) { data, resp, err in
            DispatchQueue.main.async {
                if let err = err {
                    errorMsg = "网络错误：\(err.localizedDescription)"
                    isLoading = false
                    return
                }
                
                guard let data = data else {
                    errorMsg = "服务器无返回"
                    isLoading = false
                    return
                }
                
                if let str = String(data: data, encoding: .utf8) {
                    let cleanLink = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let videoUrl = URL(string: cleanLink) {
                        self.player = AVPlayer(url: videoUrl)
                        self.player?.play()
                    } else {
                        errorMsg = "视频链接格式错误"
                    }
                } else {
                    errorMsg = "无法解析返回数据"
                }
                isLoading = false
            }
        }.resume()
    }
}
