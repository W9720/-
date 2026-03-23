import SwiftUI
import AVKit

struct ContentView: View {
    // 👉 只需要改这一行！改成你的API地址
    let videoAPIURL = "https://api.yujn.cn/api/zzxjj.php?type=video"
    
    @State private var videoURL: URL?
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            if let url = videoURL {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        player = AVPlayer(url: url)
                        player?.play()
                    }
            } else {
                ProgressView("加载视频中...")
                    .foregroundColor(.white)
                    .scaleEffect(2)
            }
        }
        .background(.black)
        .onAppear(perform: loadVideoFromAPI)
        .preferredColorScheme(.dark)
    }
    
    // 从API获取视频地址（自动解析纯文本VIDEO链接）
    func loadVideoFromAPI() {
        guard let url = URL(string: videoAPIURL) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, err in
            if let data = data, let videoStr = String(data: data, encoding: .utf8) {
                if let videoURL = URL(string: videoStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    DispatchQueue.main.async {
                        self.videoURL = videoURL
                    }
                }
            }
        }.resume()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
