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

// 欢迎页
struct SplashView: View {
    @State private var show = false
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("By 喜爱民谣").foregroundColor(.white)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now()+1) {
                show = true
            }
        }
        .fullScreenCover(isPresented: $show) {
            FinalVideoView()
        }
    }
}

// 最终不黑屏版
struct FinalVideoView: View {
    @State private var player: AVPlayer = AVPlayer(url: URL(string: "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_1MB.mp4")!)
    @State private var isLoading = false
    @State private var log = "开始"
    
    let api = "https://api.yujn.cn/api/zzxjj.php?type=video"
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // UIKit 播放器（绝对不黑屏）
            VideoUIView(player: player)
                .ignoresSafeArea()
            
            // 日志
            VStack {
                Text(log).foregroundColor(.green).font(.system(size: 12))
                Spacer()
            }
            
            if isLoading {
                ProgressView().tint(.white).scaleEffect(1.5)
            }
        }
        .onAppear {
            player.play()
            loadVideo()
        }
        .onTapGesture {
            player.timeControlStatus == .playing ? player.pause() : player.play()
        }
        .gesture(DragGesture().onEnded { v in
            if v.translation.height < -100 {
                loadVideo()
            }
        })
    }
    
    // 全修复加载
    private func loadVideo() {
        isLoading = true
        log = "正在请求..."
        
        var req = URLRequest(url: URL(string: api)!)
        // 最强浏览器伪装
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        req.setValue("https://api.yujn.cn", forHTTPHeaderField: "Referer")
        req.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: req) { data, _, err in
            DispatchQueue.main.async {
                if let err = err {
                    log = "错误：\(err.localizedDescription)"
                    isLoading = false
                    return
                }
                
                guard let data = data, let str = String(data: data, encoding: .utf8) else {
                    log = "无数据返回"
                    isLoading = false
                    return
                }
                
                log = "返回：\(str.prefix(50))"
                
                let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let url = URL(string: clean), clean.starts(with: "http") else {
                    log = "链接无效"
                    isLoading = false
                    return
                }
                
                // 替换视频
                player.replaceCurrentItem(with: AVPlayerItem(url: url))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    player.play()
                    isLoading = false
                    log = "播放中..."
                }
            }
        }.resume()
    }
}

// UIKit 视频层（永不黑屏）
struct VideoUIView: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        let layer = AVPlayerLayer(player: player)
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
