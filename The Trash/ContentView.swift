import SwiftUI
import Supabase
import Auth

struct ContentView: View {
    // 确保使用 .shared 单例以防止内存暴涨
    @StateObject private var viewModel = TrashViewModel(classifier: RealClassifierService.shared)
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showReportSheet = false
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 30) {
                // --- 顶部栏 ---
                HStack {
                    Text("The Trash")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // 登出按钮
                    Button(action: {
                        Task { await authVM.signOut() }
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 40)
                
                // --- 取景/图片区域 ---
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 350)
                        .shadow(radius: 10)
                    
                    if viewModel.appState == .analyzing {
                        ProgressView()
                            .scaleEffect(1.5)
                    } else if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 350)
                            .cornerRadius(24)
                            .clipped()
                    } else {
                        VStack {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("Tap Camera to Scan")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .onTapGesture {
                    showCamera = true
                }
                
                // --- 结果卡片 ---
                if case .finished(let result) = viewModel.appState {
                    ResultCard(result: result, onReport: {
                        self.showReportSheet = true
                    })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
                
                // --- 底部按钮 ---
                Button(action: {
                    showCamera = true
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Identify Trash")
                    }
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(16)
                    .shadow(radius: 5)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(selectedImage: $capturedImage)
        }
        // 🔥 修复：使用 iOS 17 新版 onChange 语法
        // 旧版: .onChange(of: capturedImage) { newImage in ... }
        // 新版: Closure 接收两个参数 (oldValue, newValue)
        .onChange(of: capturedImage) { _, newImage in
            if let img = newImage {
                viewModel.analyzeImage(image: img)
            }
        }
        .sheet(isPresented: $showReportSheet) {
            if case .finished(let result) = viewModel.appState,
               let image = capturedImage {
                ReportView(
                    predictedResult: result,
                    image: image,
                    userId: authVM.session?.user.id
                )
            }
        }
        .animation(.spring(), value: viewModel.appState)
    }
}

// ResultCard 组件保持不变，为了完整性这里也保留
struct ResultCard: View {
    let result: TrashAnalysisResult
    var onReport: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(result.category)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(result.color)
                Spacer()
                Text(String(format: "Confidence: %.0f%%", result.confidence * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Divider()
            HStack {
                Text("Item:")
                    .fontWeight(.semibold)
                Text(result.itemName)
            }
            HStack(alignment: .top) {
                Text("Tip:")
                    .fontWeight(.semibold)
                Text(result.actionTip)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
            
            Button(action: onReport) {
                HStack {
                    Image(systemName: "exclamationmark.bubble.fill")
                    Text("Report Incorrect Result")
                }
                .font(.footnote)
                .foregroundColor(.red.opacity(0.8))
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}
