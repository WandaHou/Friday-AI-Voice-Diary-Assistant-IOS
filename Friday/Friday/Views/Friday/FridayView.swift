import SwiftUI
import UIKit
import Foundation
import Lottie

struct FridayView: View {
    @EnvironmentObject private var fridayState: FridayState
    @State private var buttonTitle: String = "Asleep"
    @State private var isGifPlaying: Bool = false
    @State private var showPatMessage: Bool = false
    
    // MARK: - Main View
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Message space (always present but invisible)
            Text("Your cat is patted")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .opacity(showPatMessage ? 1 : 0)
                .padding(.bottom, 70)
            
            // GIF Image Button
            AnimatedImageView()
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
            Text("Friday1.0")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            // "is" Label
            Text("is")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            // Awake/Asleep Button
            Button(action: {
                fridayState.voiceDetectorActive.toggle()
            }) {
                Text(fridayState.voiceDetectorActive ? "Awake" : "Asleep")
                    .font(.system(size: 18, weight: .bold))
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Animated Image View
struct AnimatedImageView: View {
    @State private var playbackSpeed: Double = 0.0
    @EnvironmentObject private var fridayState: FridayState
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    private let threshold: Float = AudioRecorder.shared.threshold
    private let maxDB: Float = -20.0
    
    var body: some View {
        LottieView(animation: .named("phonograph"),
                  speed: playbackSpeed)
            .onChange(of: fridayState.voiceDetectorActive) { isActive in
                if !isActive {
                    playbackSpeed = 0.0
                }
            }
            .onReceive(timer) { _ in
                guard fridayState.voiceDetectorActive else {
                    if playbackSpeed != 0.0 {
                        playbackSpeed = 0.0
                    }
                    return
                }
                
                Task {
                    if let level = await AudioRecorder.shared.currentAudioLevel {
                        updateSpeed(for: level)
                    }
                }
            }
    }
    
    private func updateSpeed(for level: Float) {
        if level > threshold {
            let speed = (level - threshold) / (maxDB - threshold)
            let clampedSpeed = Double(speed.clamped(to: 0...1))
            playbackSpeed = 0.4 + (clampedSpeed * 1.6)
        } else {
            playbackSpeed = 0.4
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
        .environmentObject(FridayState.shared)
} 
