import SwiftUI
import Supabase
import Auth
import Contacts

// MARK: - Enums
enum SwipeDirection {
    case left
    case right
}

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            VerifyView()
                .tabItem { Label("Verify", systemImage: "camera.viewfinder") }
                .tag(0)
            
            FriendView()
                .tabItem { Label("Friends", systemImage: "person.2.fill") }
                .tag(1)
            
            ArenaView()
                .tabItem { Label("Arena", systemImage: "flame.fill") }
                .tag(2)
            
            RewardView()
                .tabItem { Label("Reward", systemImage: "gift.fill") }
                .tag(3)
            
            AccountView()
                .tabItem { Label("Account", systemImage: "person.circle.fill") }
                .tag(4)
        }
        .accentColor(.blue)
    }
}

// MARK: - 1. Verify View (iOS 18 & Tab-Switch Bug Fixed)
struct VerifyView: View {
    @StateObject private var viewModel = TrashViewModel(classifier: RealClassifierService.shared)
    @StateObject private var cameraManager = CameraManager()
    
    // UI State
    @State private var cardOffset: CGSize = .zero
    @State private var showingFeedbackForm = false
    @State private var isCameraActive = false
    
    // Form Data
    @State private var selectedFeedbackCategory = "General Trash"
    @State private var feedbackItemName = ""
    let trashCategories = ["Recyclable", "Hazardous", "Compostable", "General Trash", "Electronic"]
    
    // Computed states for cleaner logic
    var showFeedbackForm: Bool {
        if case .collectingFeedback = viewModel.appState, showingFeedbackForm { return true }
        return false
    }
    
    var isPreviewState: Bool {
        cameraManager.capturedImage == nil && viewModel.appState == .idle
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("The Trash")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // --- Camera/Image Area ---
                GeometryReader { geo in
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                        
                        if let image = cameraManager.capturedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .cornerRadius(24)
                                .clipped()
                        } else if isCameraActive {
                            CameraPreview(cameraManager: cameraManager)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "camera.aperture")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary.opacity(0.4))
                                Text("Ready to identify").foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(maxHeight: 360) // Reduced height to accommodate iOS 18 TabBar
                .padding(.horizontal)
                .padding(.top, 10)
                
                // --- Dynamic Interaction Area ---
                ZStack {
                    if case .finished(let result) = viewModel.appState, !showingFeedbackForm {
                        SwipeableResultCard(result: result, offset: $cardOffset) { direction in
                            handleSwipe(direction: direction, result: result)
                        }
                    }
                    
                    if showFeedbackForm {
                        FeedbackFormView(
                            selectedCategory: $selectedFeedbackCategory,
                            itemName: $feedbackItemName,
                            categories: trashCategories
                        )
                    }
                }
                .frame(height: 180)
                
                Spacer(minLength: 10)
                
                // --- Main Action Button ---
                Button(action: handleMainButtonTap) {
                    HStack {
                        if viewModel.appState == .analyzing {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: buttonIcon)
                            Text(buttonText)
                        }
                    }
                    .font(.headline).fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(showFeedbackForm ? Color.green : Color.blue)
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 15) // Extra padding for visual breathing room
                .disabled(viewModel.appState == .analyzing)
            }
        }
        // Prevents button from being covered by Tab Bar
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 15)
        }
        .onDisappear {
            cameraManager.stop()
        }
        .onReceive(cameraManager.$capturedImage) { img in
            if let img = img { viewModel.analyzeImage(image: img) }
        }
    }
    
    // Dynamic Icon & Text Logic
    private var buttonIcon: String {
        if showFeedbackForm { return "paperplane.fill" }
        if isCameraActive && !isPreviewState { return "arrow.clockwise" }
        return isCameraActive ? "camera.shutter.button.fill" : "camera.fill"
    }
    
    private var buttonText: String {
        if showFeedbackForm { return "Submit" }
        if isCameraActive && !isPreviewState { return "Retake" }
        return isCameraActive ? "Identify" : "Open Camera"
    }
    
    // MARK: - Handlers
    private func handleSwipe(direction: SwipeDirection, result: TrashAnalysisResult) {
        let generator = UINotificationFeedbackGenerator()
        if direction == .right {
            generator.notificationOccurred(.success)
            viewModel.handleCorrectFeedback()
            withAnimation(.easeIn(duration: 0.3)) { cardOffset.width = 500 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { finishFlowAndReset() }
        } else {
            generator.notificationOccurred(.warning)
            withAnimation(.easeIn(duration: 0.3)) { cardOffset.width = -500 }
            viewModel.prepareForIncorrectFeedback(wrongResult: result)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring()) {
                    self.showingFeedbackForm = true
                    self.cardOffset = .zero
                }
            }
        }
    }
    
    private func handleMainButtonTap() {
        if showFeedbackForm {
            submitFeedback()
        } else if !isCameraActive {
            withAnimation { isCameraActive = true }
            cameraManager.start()
        } else if isPreviewState {
            cameraManager.takePhoto()
        } else {
            finishFlowAndReset()
            cameraManager.start()
        }
    }
    
    private func submitFeedback() {
        guard case .collectingFeedback(let originalResult) = viewModel.appState,
              let currentImage = cameraManager.capturedImage else { return }
        Task {
            await viewModel.submitCorrection(image: currentImage, originalResult: originalResult, correctedCategory: selectedFeedbackCategory, correctedName: feedbackItemName)
            finishFlowAndReset()
        }
    }
    
    private func finishFlowAndReset() {
        withAnimation {
            showingFeedbackForm = false
            cardOffset = .zero
            selectedFeedbackCategory = "General Trash"
            feedbackItemName = ""
        }
        viewModel.reset()
        cameraManager.reset()
    }
}

// MARK: - 2. Friend View
struct FriendView: View {
    @StateObject private var friendService = FriendService()
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                if friendService.friends.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.slash.fill").font(.system(size: 60)).foregroundColor(.secondary)
                        Text("No friends yet").font(.title2).bold()
                        Button("Sync Contacts") { Task { await friendService.findFriendsFromContacts() } }.buttonStyle(.borderedProminent)
                    }
                } else {
                    List(friendService.friends) { friend in
                        HStack {
                            Text("\(friend.rank)").bold().frame(width: 30)
                            Text(friend.username ?? "Anonymous")
                            Spacer()
                            Text("\(friend.credits) pts").foregroundColor(.blue)
                        }
                    }.listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Leaderboard")
        }
    }
}

// MARK: - 3. Reward View
struct RewardView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "gift.fill").font(.system(size: 60)).foregroundColor(.orange)
                Text("Rewards Coming Soon").font(.headline)
            }.navigationTitle("Rewards")
        }
    }
}

// MARK: - 4. Account View (Guest Support)
struct AccountView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showBindPhoneSheet = false
    @State private var showBindEmailSheet = false
    @State private var inputPhone = "+1"
    @State private var inputEmail = ""
    @State private var inputOTP = ""
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(authVM.isAnonymous ? Color.gray.opacity(0.1) : Color.blue.opacity(0.1))
                            .frame(width: 60, height: 60)
                            .overlay(Image(systemName: "person.fill").foregroundColor(authVM.isAnonymous ? .gray : .blue))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if authVM.isAnonymous {
                                Text("Guest User").font(.headline)
                                Text("Link account to save data").font(.caption).foregroundColor(.orange)
                            } else {
                                Text(authVM.session?.user.email ?? authVM.session?.user.phone ?? "Member").font(.headline)
                                Text("Verified Member").font(.caption).foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: { Text("Profile") }
                
                Section {
                    HStack {
                        Label("Email", systemImage: "envelope.fill")
                        Spacer()
                        if let email = authVM.session?.user.email, !email.isEmpty {
                            Text("Linked").font(.caption).bold().foregroundColor(.green)
                        } else {
                            Button("Link") { showBindEmailSheet = true }.foregroundColor(.blue)
                        }
                    }
                    HStack {
                        Label("Phone", systemImage: "phone.fill")
                        Spacer()
                        if let phone = authVM.session?.user.phone, !phone.isEmpty {
                            Text("Linked").font(.caption).bold().foregroundColor(.green)
                        } else {
                            Button("Link") { showBindPhoneSheet = true }.foregroundColor(.blue)
                        }
                    }
                } header: { Text("Account Binding") }
                
                Section {
                    Button(action: { Task { await authVM.signOut() } }) {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right").foregroundColor(.red)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("My Account")
            .sheet(isPresented: $showBindPhoneSheet) {
                BindPhoneSheet(inputPhone: $inputPhone, inputOTP: $inputOTP, authVM: authVM, isPresented: $showBindPhoneSheet)
            }
            .sheet(isPresented: $showBindEmailSheet) {
                BindEmailSheet(inputEmail: $inputEmail, authVM: authVM, isPresented: $showBindEmailSheet)
            }
        }
    }
}

// MARK: - Binding Sheets
struct BindPhoneSheet: View {
    @Binding var inputPhone: String
    @Binding var inputOTP: String
    @ObservedObject var authVM: AuthViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                if !authVM.showOTPInput {
                    Section {
                        TextField("Phone (+1...)", text: $inputPhone).keyboardType(.phonePad)
                        Button("Send Code") { Task { await authVM.bindPhone(phone: inputPhone) } }
                    }
                } else {
                    Section {
                        TextField("Code", text: $inputOTP).keyboardType(.numberPad)
                        Button("Verify & Link") {
                            Task {
                                await authVM.confirmBindPhone(phone: inputPhone, token: inputOTP)
                                isPresented = false
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bind Phone")
        }
    }
}

struct BindEmailSheet: View {
    @Binding var inputEmail: String
    @ObservedObject var authVM: AuthViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $inputEmail).keyboardType(.emailAddress).autocapitalization(.none)
                    Button("Send Link") {
                        Task {
                            await authVM.bindEmail(email: inputEmail)
                            isPresented = false
                        }
                    }
                }
            }
            .navigationTitle("Bind Email")
        }
    }
}

// MARK: - Components

struct SwipeableResultCard: View {
    let result: TrashAnalysisResult
    @Binding var offset: CGSize
    var onSwiped: (SwipeDirection) -> Void
    var body: some View {
        ResultCardContent(result: result)
            .offset(x: offset.width)
            .rotationEffect(.degrees(Double(offset.width / 15)))
            .gesture(DragGesture().onChanged { offset = $0.translation }.onEnded { gesture in
                if gesture.translation.width < -100 { onSwiped(.left) }
                else if gesture.translation.width > 100 { onSwiped(.right) }
                else { withAnimation(.spring()) { offset = .zero } }
            })
    }
}

struct ResultCardContent: View {
    let result: TrashAnalysisResult
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(result.category).font(.headline).foregroundColor(result.color)
                Spacer()
                Text("\(Int(result.confidence * 100))%").font(.caption).bold().padding(4).background(Color.secondary.opacity(0.1)).cornerRadius(4)
            }
            Text(result.itemName).font(.title3).bold()
            Text(result.actionTip).font(.caption).foregroundColor(.secondary)
        }
        .padding().background(Color(.secondarySystemGroupedBackground)).cornerRadius(16).padding(.horizontal)
    }
}

struct FeedbackFormView: View {
    @Binding var selectedCategory: String
    @Binding var itemName: String
    let categories: [String]
    var body: some View {
        VStack(spacing: 12) {
            Picker("Category", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { Text($0) }
            }.pickerStyle(.menu)
            TextField("Item Name", text: $itemName).textFieldStyle(.roundedBorder)
        }
        .padding().background(Color(.secondarySystemGroupedBackground)).cornerRadius(16).padding(.horizontal)
    }
}
