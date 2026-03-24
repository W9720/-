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
            DebugVideoView()
        }
    }
}

// 🔥 带完整日志的诊断版，直接显示所有关键信息
struct DebugVideoView: View {
    @State private var player: AVPlayer = AVPlayer()
    @State private var isLoading = false
    @State private var logText = "等待请求..."
    @State private var history: [URL] = []
    @State private var index = 0
    
    let api = "http://api.yujn.cn/api/zzxjj.php?type=json"
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoLayerView(player: player).ignoresSafeArea()
            
            // 悬浮日志面板（关键！直接看问题）
            VStack(alignment: .leading, spacing: 4) {
                Text(logText)
                    .foregroundColor(.yellow)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(5)
                    .padding(8)
                    .background(Color.black.opacity(0.7))
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
        .onAppear { loadFirst() }
        .onTapGesture {
            player.timeControlStatus == .playing ? player.pause() : player.play()
        }
        .gesture(DragGesture().onEnded { v in
            v.translation.height < -120 ? loadNew() : backPrev()
        })
    }
    
    private func loadFirst() { history.isEmpty ? loadNew() : () }
    
    // 核心：带完整日志的请求+解析
    private func loadNew() {
        isLoading = true
        logText = "正在请求接口..."
        
        guard let url = URL(string: api) else {
            logText = "❌ 接口URL无效"
            isLoading = false
            return
        }
        
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 20
        
        URLSession.shared.dataTask(with: req) { data, resp, err in
            DispatchQueue.main.async {
                isLoading = false
                
                // 1. 检查网络错误
                if let err = err {
                    logText = "❌ 网络错误: \(err.localizedDescription)"
                    return
                }
                
                // 2. 检查数据是否为空
                guard let data = data else {
                    logText = "❌ 接口返回空数据"
                    return
                }
                
                // 3. 打印原始JSON（关键！看接口真实返回）
                if let rawStr = String(data: data, encoding: .utf8) {
                    logText = "✅ 原始JSON:\n\(rawStr.prefix(200))"
                }
                
                // 4. 解析JSON（匹配你的格式）
                struct Resp: Codable {
                    let code: Int
                    let data: String
                }
                
                do {
                    let res = try JSONDecoder().decode(Resp.self, from: data)
                    
                    // 5. 检查code和data
                    guard res.code == 200 else {
                        logText = "❌ code错误: \(res.code)"
                        return
                    }
                    
                    guard !res.data.isEmpty, let videoUrl = URL(string: res.data) else {
                        logText = "❌ 视频地址无效:\n\(res.data.prefix(100))"
                        return
                    }
                    
                    // 6. 检查播放器状态
                    logText = "✅ 解析成功:\n\(res.data.prefix(100))"
                    
                    // 🔥 关键修复：强制替换+延迟播放
                    player.replaceCurrentItem(with: AVPlayerItem(url: videoUrl))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        player.play()
                        logText = "▶️ 正在播放:\n\(res.data.prefix(100))"
                    }
                    
                    history.append(videoUrl)
                    index = history.count - 1
                    
                } catch {
                    logText = "❌ JSON解析错误:\n\(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    private func backPrev() {
        guard index > 0 else { return }
        index -= 1
        let url = history[index]
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
        logText = "◀️ 返回上一个:\n\(url.absoluteString.prefix(100))"
    }
}

// 底层播放层（绝对不黑屏）
struct VideoLayerView: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        let layer = AVPlayerLayer(player: player)
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspectFill
        layer.backgroundColor = UIColor.black.cgColor
        view.layer.addSublayer(layer)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
