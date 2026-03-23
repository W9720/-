import SwiftUI
import AVKit
import WebKit

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

// 全屏视频播放器（修复黑屏！）
struct FullScreenVideoView: View {
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMsg = ""
    
    let apiUrl = "https://api.yujn.cn/api/zzxjj.php"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    Text("加载视频中...")
                        .foregroundColor(.white)
                }
            } else if !errorMsg.isEmpty {
                Text(errorMsg)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
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
        .onAppear(perform: loadAndPlayVideo)
    }
    
    // MARK: - 核心修复：清理API返回的垃圾字符，提取真实视频地址
    private func loadAndPlayVideo() {
        guard let url = URL(string: apiUrl) else {
            errorMsg = "接口地址错误"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, err in
            DispatchQueue.main.async {
                if let err = err {
                    errorMsg = "网络错误：\(err.localizedDescription)"
                    isLoading = false
                    return
                }
                
                guard let data = data,
                      let text = String(data: data, encoding: .utf8) else {
                    errorMsg = "接口返回空内容"
                    isLoading = false
                    return
                }
                
                // 🔥 关键修复：清理所有非链接内容，提取真实 mp4 地址
                let cleaned = text
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: "\r", with: "")
                    .replacingOccurrences(of: " ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                print("清理后的视频地址：\(cleaned)")
                
                guard let videoUrl = URL(string: cleaned) else {
                    errorMsg = "无效视频地址"
                    isLoading = false
                    return
                }
                
                // 创建播放器
                self.player = AVPlayer(url: videoUrl)
                self.isLoading = false
            }
        }.resume()
    }
}
