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
            Text("By 喜爱民谣").foregroundColor(.white)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now()+1) { show = true }
        }
        .fullScreenCover(isPresented: $show) {
            FinalVideoView()
        }
    }
}

struct FinalVideoView: View {
    @State private var player: AVPlayer = AVPlayer(url: URL(string: "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_1MB.mp4")!)
    @State private var isLoading = false
    @State private var log = "开始"
    
    let api = "https://api.yujn.cn/api/zzxjj.php?type=video"
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoUIView(player: player).ignoresSafeArea()
            
            VStack{ Text(log).foregroundColor(.green); Spacer() }
            
            if isLoading { ProgressView().tint(.white).scaleEffect(1.5) }
        }
        .onAppear {
            player.play()
            loadVideo()
        }
        .onTapGesture {
            player.timeControlStatus == .playing ? player.pause() : player.play()
        }
        .gesture(DragGesture().onEnded { v in
            if v.translation.height < -100 { loadVideo() }
        })
    }
    
    private func loadVideo() {
        isLoading = true
        log = "请求中..."
        
        var req = URLRequest(url: URL(string: api)!)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json,text/plain", forHTTPHeaderField: "Accept")
        req.setValue("https://api.yujn.cn", forHTTPHeaderField: "Origin")
        req.timeoutInterval = 15
        
        URLSession.shared.dataTask(with: req) { data, _, err in
            DispatchQueue.main.async {
                guard let data = data, !data.isEmpty,
                      let str = String(data: data, encoding: .utf8),
                      !str.isEmpty else {
                    log = "⚠️ 接口屏蔽iOS，无数据返回"
                    isLoading = false
                    return
                }
                
                log = "✅ 成功获取视频"
                let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
                if let url = URL(string: clean) {
                    player.replaceCurrentItem(with: AVPlayerItem(url: url))
                    player.play()
                }
                isLoading = false
            }
        }.resume()
    }
}

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
