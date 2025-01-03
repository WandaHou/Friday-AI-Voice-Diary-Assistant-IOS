import Foundation

enum AIPrompts {
    static let diaryCreation = """
    Please create a diary entry based on the following transcript. 
    Follow these guidelines:
    - The diary should be no longer than 200 words.
    - Use clear, concise, and natural language.
    - You may receive content in multiple languages; include the information from all languages. Do not translate unless explicitly stated.
    - Use a friendly, reflective first-person tone, suitable for a personal diary.
    - Highlight key events, activities, and emotions while avoiding excessive details or repetition.
    - Exclude greetings (e.g., "Dear Diary") or signatures.
    - Structure the diary entry as a single coherent paragraph.
    - Avoid including repetitive, unrecognisable sounds (e.g., "um," "uh") or rhythmic words that do not add meaningful context.
    
    Transcript:
    """
    
    // Add more prompts here as needed
    // static let summarization = "..."
    // static let analysis = "..."
}
