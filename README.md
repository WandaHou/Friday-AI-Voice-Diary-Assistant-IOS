# AI Voice Diary Assistant 🎧

IOS application that transforms your spoken words into beautifully crafted diary entries. Like a faithful companion, it listens to your voice and helps you maintain a digital diary without the need for manual writing.

## Features 🌟

### 1. Voice Recording with Visual Feedback
- Interactive phonograph animation that responds to your voice
- Visual feedback through animation speed based on voice intensity
- Simple tap-to-pat interaction with the phonograph

### 2. Smart Audio Processing
- Automatic voice detection and recording
- Silence detection for optimal recording segments
- Background audio processing with minimal battery impact

### 3. Advanced Transcription
- Powered by OpenAI's Whisper API for accurate speech-to-text
- Supports multiple languages with automatic translation to English
- Organized timestamp-based transcription storage

### 4. AI-Powered Diary Generation
- Uses GPT-4 Turbo to convert transcriptions into coherent diary entries
- Customizable diary formatting through system prompts
- Intelligent handling of long recordings with chunked processing

### 5. Customizable Experience
- Adjustable system prompts for personalized diary style
- Default guidelines for consistent diary formatting
- Easy-to-use profile management

## Technical Highlights 🛠

- Built with SwiftUI for modern iOS UI
- Actor-based concurrent architecture
- Protocol-oriented design for better testability
- Robust permission handling
- Efficient file management system
- Clean separation of concerns with MVVM architecture

## Requirements 📱

- iOS 16.0 or later
- OpenAI API key for transcription and diary generation
- Microphone permissions
- Notification permissions (optional)

## Privacy 🔒

Designed with privacy in mind:
- All audio recordings are processed locally before transcription
- Transcriptions are stored securely on your device
- OpenAI API interactions follow best security practices

## Getting Started 🚀

1. Launch the app
2. Grant necessary permissions
3. Tap the "Awake" button to start voice detection
4. Speak naturally about your day
5. Use "Transcribe" to convert recordings to text
6. Generate your diary entry with "Generate Diary"

## Customization ⚙️

Visit the Profile tab to customize your diary generation guidelines:
- Adjust writing style
- Set length preferences
- Modify formatting rules
- Add custom instructions

## Coming Soon 🔜

- Forum feature for community interaction
- Enhanced cache management
- Additional customization options
- Performance optimizations

---
