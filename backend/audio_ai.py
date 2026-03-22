import os
import numpy as np
import librosa
import pickle
import noisereduce as nr
from keras.models import load_model
import config as cfg

class AudioEngine:
    def __init__(self):
        print("[Audio AI] Initializing Engine...")
        if not os.path.exists(cfg.AUDIO_MODEL_PATH):
            raise FileNotFoundError(f"Audio Model not found: {cfg.AUDIO_MODEL_PATH}")
        
        self.model = load_model(cfg.AUDIO_MODEL_PATH)
        with open(cfg.LABEL_ENCODER_PATH, 'rb') as f:
            self.lb = pickle.load(f)
        self.labels = self.lb.classes_
        
        # Audio Config (Must match training)
        self.SAMPLE_RATE = 22050
        self.DURATION = 3
        self.N_MFCC = 40
        self.MAX_LEN = int(self.SAMPLE_RATE * self.DURATION)
        print("[Audio AI] Engine Ready.")

    def preprocess_and_denoise(self, audio_path):
        """ Loads audio, applies noise reduction, and returns clean signal """
        try:
            # 1. Load Audio
            y, sr = librosa.load(audio_path, sr=self.SAMPLE_RATE)
            
            # 2. Noise Reduction (Spectral Gating)
            if len(y) > sr*0.5:
                noise_part = y[0:int(sr*0.5)]
                y_clean = nr.reduce_noise(y=y, sr=sr, y_noise=noise_part, prop_decrease=0.8)
            else:
                y_clean = nr.reduce_noise(y=y, sr=sr)
                
            return y_clean
        except Exception as e:
            print(f"[Audio Error] Preprocessing failed: {e}")
            return None

    def analyze_audio_timeline(self, audio_path):
        """ Returns a list of probability dictionaries per 3s chunk """
        clean_audio = self.preprocess_and_denoise(audio_path)
        if clean_audio is None: return []
        
        # --- THE FIX: USE INTEGER DIVISION (//) ---
        # This ignores any partial chunk at the end.
        # 57s // 3 = 19 chunks.
        # 59s // 3 = 19 chunks. (Drops the last 2 seconds)
        total_samples = len(clean_audio)
        num_chunks = int(total_samples // self.MAX_LEN)
        
        timeline_probs = []
        
        for i in range(num_chunks):
            start = i * self.MAX_LEN
            end = start + self.MAX_LEN
            chunk = clean_audio[start:end]
            
            # Pad/Truncate (Just in case)
            if len(chunk) < self.MAX_LEN:
                chunk = np.pad(chunk, (0, self.MAX_LEN - len(chunk)), 'constant')
            else:
                chunk = chunk[:self.MAX_LEN]
                
            # MFCC Extraction
            mfccs = librosa.feature.mfcc(y=chunk, sr=self.SAMPLE_RATE, n_mfcc=self.N_MFCC)
            mfccs = mfccs.T # (Time, Features)
            
            # Predict
            input_data = np.expand_dims(mfccs, axis=0) # (1, Time, Feat)
            preds = self.model.predict(input_data, verbose=0)[0]
            
            # Store Dictionary
            prob_dict = {label: float(score) for label, score in zip(self.labels, preds)}
            
            timeline_probs.append({
                "start_time": i * self.DURATION,
                "end_time": (i+1) * self.DURATION,
                "probs": prob_dict
            })
            
        return timeline_probs