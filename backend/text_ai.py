# text_ai.py
import speech_recognition as sr
from deep_translator import GoogleTranslator
from transformers import pipeline
import os

class TextEngine:
    def __init__(self):
        print("[Text AI] Initializing Local Professional Model...")
        
        # 1. Setup Path to Local Model
        # This looks for: Main Project/model/text_model/final_model
        current_dir = os.path.dirname(os.path.abspath(__file__))
        
        # Navigate UP from 'main codes' to 'Main Project', then DOWN to model folder
        self.model_path = os.path.abspath(os.path.join(current_dir, "..", "models", "text_model1", "final_model"))
        
        if not os.path.exists(self.model_path):
            print(f"❌ CRITICAL ERROR: Model not found at {self.model_path}")
            self.classifier = None
        else:
            try:
                # Load the pipeline from your local folder (Offline Mode)
                self.classifier = pipeline(
                    "text-classification", 
                    model=self.model_path, 
                    tokenizer=self.model_path,
                    device=-1, # CPU (Use 0 for GPU)
                    top_k=None,
                    framework="pt"
                )
                print("[Text AI] Engine Ready & Loaded Successfully.")
            except Exception as e:
                print(f"[Text AI] Error loading model: {e}")
                self.classifier = None
        
        self.recognizer = sr.Recognizer()
        self.translator = GoogleTranslator(source='auto', target='en')

    def transcribe_and_translate(self, audio_path):
        """ Reads audio file -> Text -> English Text """
        try:
            with sr.AudioFile(audio_path) as source:
                audio_data = self.recognizer.record(source)
            
            # Speech to Text
            text = self.recognizer.recognize_google(audio_data)
            print(f"[Text AI] Transcribed: {text}")
            
            # Translate to English (if needed)
            translated_text = self.translator.translate(text)
            if translated_text != text:
                print(f"[Text AI] Translated: {translated_text}")
            
            return translated_text
            
        except sr.UnknownValueError:
            print("[Text AI] Audio was silent or unintelligible.")
            return ""
        except Exception as e:
            print(f"[Text AI] Audio Error: {e}")
            return ""

    def analyze_text(self, text):
        """ Analyzes the emotion of the English text """
        if not text or self.classifier is None:
            return None

        # 1. Run the Model
        results = self.classifier(text)[0] 
        raw_probs = {item['label']: item['score'] for item in results}
        
        # 2. Map Professional Labels (lowercase) to Tracemind Labels (Capitalized)
        # The model uses 'joy', 'anger' -> We need 'Happy', 'Angry'
        final_probs = {
            'Angry': raw_probs.get('anger', 0.0),
            'Disgust': raw_probs.get('disgust', 0.0),
            'Fear': raw_probs.get('fear', 0.0),
            'Happy': raw_probs.get('joy', 0.0),    # Map 'joy' to 'Happy'
            'Neutral': raw_probs.get('neutral', 0.0),
            'Sad': raw_probs.get('sadness', 0.0),  # Map 'sadness' to 'Sad'
            'Surprise': raw_probs.get('surprise', 0.0)
        }
        
        return final_probs