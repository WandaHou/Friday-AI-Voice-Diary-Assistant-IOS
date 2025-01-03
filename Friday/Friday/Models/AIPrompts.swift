import Foundation

enum AIPrompts {
    static let diaryCreation = """
    Please create a diary entry based on the following transcript. 
    Follow these guidelines:
    - The diary should be no longer than 200 words but no shorter than 50 words.
    - Use clear, concise, and natural language.
    - You may receive content in multiple languages; include the information from all languages. Do not translate unless explicitly stated.
    - Use a first-person tone, suitable for a personal diary.
    - Focus on describing activities and events as they are mentioned in the transcript. If necessary, highlight key events or activities, but avoid unnecessary elaboration.
    - Do not infer or summarise emotions, moods, or feelings beyond what is explicitly stated in the transcript.
    - Exclude greetings (e.g., "Dear Diary") or signatures.
    - Structure the diary entry as a single coherent paragraph.
    - Avoid including repetitive, unrecognisable sounds (e.g., "um," "uh") or rhythmic words that do not add meaningful context.
    - If the transcript contains no meaningful content, provide a brief note such as "No significant activity to record today."

    Transcript:
    """
    
    // Add more prompts here as needed
    // static let summarization = "..."
    // static let analysis = "..."
}
