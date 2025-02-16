import SwiftUI
import UIKit
import Combine
import Lottie

struct FridayView: View {
    @StateObject private var viewModel = FridayViewModel()
    @State private var showPatMessage: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Message space (always present but invisible)
            Text("Your cat is patted")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .opacity(showPatMessage ? 1 : 0)
                .padding(.bottom, 70)
            
            // GIF Image Button
            AnimatedImageView(viewModel: viewModel)
                .frame(width: 200, height: 200)
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation {
                            showPatMessage = true
                            print("Your cat is patted")
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation {
                                showPatMessage = false
                            }
                        }
                    }
                )
                .padding(.bottom, 70)
            
            // Version Label
            Text("Friday0.1")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            // "is" Label
            Text("is")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            // Awake/Asleep Button
            Button(action: {
                Task {
                    await viewModel.toggleVoiceDetector()
                }
            }) {
                Text(viewModel.voiceDetectorActive ? "Awake" : "Asleep")
                    .font(.system(size: 18, weight: .bold))
            }
            
            // Add Transcribe Button
            Button(action: {
                Task {
                    try? await viewModel.transcribeRecordings()
                }
            }) {
                HStack {
                    Text("Transcribe🎧")
                        .font(.system(size: 18, weight: .bold))
                    if viewModel.isTranscribing {
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isTranscribing)
            
            // Add Generate Diary Button
            Button(action: {
                Task {
                    try? await viewModel.generateDiary()
                }
            }) {
                HStack {
                    Text("Generate Diary📝")
                        .font(.system(size: 18, weight: .bold))
                    if viewModel.isGeneratingDiary {
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isGeneratingDiary)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Animated Image View
struct AnimatedImageView: View {
    @State private var playbackSpeed: Double = 0.0
    @ObservedObject var viewModel: FridayViewModel
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    private let threshold: Float
    private let maxDB: Float = -20.0
    
    init(viewModel: FridayViewModel, threshold: Float = -25.0) {
        self.viewModel = viewModel
        self.threshold = threshold
    }
    
    var body: some View {
        LottieView(animation: .named("phonograph"),
                  speed: playbackSpeed)
            .onChange(of: viewModel.voiceDetectorActive) { isActive in
                if !isActive {
                    playbackSpeed = 0.0
                }
            }
            .onReceive(timer) { _ in
                guard viewModel.voiceDetectorActive else {
                    if playbackSpeed != 0.0 {
                        playbackSpeed = 0.0
                    }
                    return
                }
                
                Task {
                    if let level = await viewModel.audioService.currentAudioLevel {
                        updateSpeed(for: level)
                    }
                }
            }
    }
    
    private func updateSpeed(for level: Float) {
        if level > threshold {
            let speed = (level - threshold) / (maxDB - threshold)
            let clampedSpeed = Double(speed.clamped(to: 0...1))
            playbackSpeed = 0.5 + (clampedSpeed * 1.5)
        } else {
            playbackSpeed = 0.5
        }
    }
}

// MARK: - Lottie View
struct LottieView: UIViewRepresentable {
    let animation: LottieAnimation?
    let speed: Double
    
    init(animation: LottieAnimation?, speed: Double) {
        self.animation = animation
        self.speed = speed
    }
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView()
        animationView.animation = animation
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.backgroundBehavior = .pauseAndRestore
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        uiView.animationSpeed = speed
        
        if speed > 0 {
            if !uiView.isAnimationPlaying {
                uiView.play()
            }
        } else {
            uiView.pause()
        }
    }
}

// MARK: - Preview
#Preview {
    FridayView()
}
