# text_ai.py
import speech_recognition as sr
from deep_translator import GoogleTranslator
from transformers import pipeline
import torch
import os

class TextEngine:
    def __init__(self):
        print("[Text AI] Initializing DeBERTa v3 Large...")
        
        # 1. Load the DeBERTa Emotion Model
        # We use a fine-tuned version compatible with standard emotions
        # If 'large' is too heavy, switch to 'bhadresh-savani/deberta-v3-base-emotion'
        device = 0 if torch.cuda.is_available() else -1
        self.classifier = pipeline(
            "text-classification", 
            model="bhadresh-savani/deberta-v3-base-emotion", 
            top_k=None, 
            device=device
        )
        
        # 2. Setup Transcriber
        self.recognizer = sr.Recognizer()
        
        # 3. Setup Translator
        self.translator = GoogleTranslator(source='auto', target='en')
        
        print("[Text AI] Engine Ready.")

    def transcribe_and_translate(self, audio_path):
        """ Extracts text from audio and translates to English """
        try:
            with sr.AudioFile(audio_path) as source:
                audio_data = self.recognizer.record(source)
                
            # A. Transcribe (Speech to Text)
            # Uses Google Web API (free/easy). For offline, use 'whisper'.
            text = self.recognizer.recognize_google(audio_data)
            print(f"[Text AI] Transcribed: {text}")
            
            # B. Translate (if not English)
            translated_text = self.translator.translate(text)
            print(f"[Text AI] Translated: {translated_text}")
            
            return translated_text
            
        except sr.UnknownValueError:
            print("[Text AI] Could not understand audio")
            return ""
        except Exception as e:
            print(f"[Text AI] Error: {e}")
            return ""

    def analyze_text(self, text):
        """ Returns a probability dictionary mapped to your standard labels """
        if not text:
            return None

        # 1. Run DeBERTa
        results = self.classifier(text)[0] # List of dicts [{'label': 'joy', 'score': 0.9}, ...]
        
        # 2. Convert to Dictionary
        raw_probs = {item['label']: item['score'] for item in results}
        
        # 3. Normalize/Map to Video Labels (Angry, Happy, etc.)
        # Video Labels: ['Angry', 'Disgust', 'Fear', 'Happy', 'Neutral', 'Sad', 'Surprise']
        final_probs = {
            'Angry': raw_probs.get('anger', 0.0),
            'Disgust': raw_probs.get('disgust', 0.0),
            'Fear': raw_probs.get('fear', 0.0),
            'Happy': raw_probs.get('joy', 0.0) + raw_probs.get('love', 0.0), # MERGE LOVE & JOY
            'Neutral': raw_probs.get('neutral', 0.0),
            'Sad': raw_probs.get('sadness', 0.0),
            'Surprise': raw_probs.get('surprise', 0.0)
        }
        
        return final_probs