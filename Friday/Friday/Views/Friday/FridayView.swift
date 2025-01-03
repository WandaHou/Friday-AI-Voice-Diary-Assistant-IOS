import SwiftUI
import UIKit
import Foundation
import Lottie

struct FridayView: View {
    @EnvironmentObject private var fridayState: FridayState
    @State private var buttonTitle: String = "Asleep"
    @State private var isGifPlaying: Bool = false
    @State private var showPatMessage: Bool = false
    @State private var isTranscribing = false
    @State private var isGeneratingDiary = false
    
    // MARK: - Main View
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
            Text("Friday0.1")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            // "is" Label
            Text("is")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            // Awake/Asleep Button
            Button(action: {
                fridayState.voiceDetectorActive.toggle()
            }) {
                Text(fridayState.voiceDetectorActive ? "Awake" : "Asleep")
                    .font(.system(size: 18, weight: .bold))
            }
            
            // Add Transcribe Button
            Button(action: {
                isTranscribing = true
                Task {
                    await transcribeRecordings()
                    isTranscribing = false
                }
            }) {
                HStack {
                    Text("Transcribe🎧")
                        .font(.system(size: 18, weight: .bold))
                    if isTranscribing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
            }
            .disabled(isTranscribing)
            
            // Add Generate Diary Button
            Button(action: {
                isGeneratingDiary = true
                Task {
                    await generateDiary()
                    isGeneratingDiary = false
                }
            }) {
                HStack {
                    Text("Generate Diary📝")
                        .font(.system(size: 18, weight: .bold))
                    if isGeneratingDiary {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
            }
            .disabled(isGeneratingDiary)
            
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
    
    static func dismantleUIView(_ uiView: LottieAnimationView, coordinator: ()) {
        // Clear Lottie's cache when view is dismantled
        LottieAnimationCache.shared?.clearCache()
        uiView.stop()
    }
}

// MARK: - Preview
#Preview {
    FridayView()
        .environmentObject(FridayState.shared)
}

func transcribeRecordings() async {
    guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return
    }
    
    let audioPath = documentsPath.appendingPathComponent("AudioRecords")
    
    do {
        _ = try await WhisperService.shared.transcribeAudioFiles(in: audioPath)
        print("Transcription completed.")
    } catch {
        print("Transcription failed.")
    }
}

func generateDiary() async {
    guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return
    }
    
    let transcriptsPath = documentsPath.appendingPathComponent("Transcripts")
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let dateString = dateFormatter.string(from: Date())
    let transcriptURL = transcriptsPath.appendingPathComponent("\(dateString).txt")
    
    do {
        _ = try await DiaryService.shared.createDiary(from: transcriptURL)
        print("Diary generated successfully")
    } catch {
        print("Failed to generate diary: \(error)")
    }
}
