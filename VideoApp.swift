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

// 最终修复版视频播放器
struct FullScreenVideoView: View {
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMsg = ""
    
    // ✅ 正确接口（带 type=video，必加！）
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
                Text(errorMsg).foregroundColor(.white).padding()
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
        guard let url = URL(string: apiUrl) else {
            errorMsg = "接口地址错误"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, err in
            DispatchQueue.main.async {
                if let data = data,
                   let str = String(data: data, .utf8) {
                    let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    if clean.isEmpty {
                        errorMsg = "接口返回空内容"
                    } else if let videoUrl = URL(string: clean) {
                        self.player = AVPlayer(url: videoUrl)
                    } else {
                        errorMsg = "视频链接格式错误"
                    }
                } else {
                    errorMsg = "网络请求失败"
                }
                isLoading = false
            }
        }.resume()
    }
}
