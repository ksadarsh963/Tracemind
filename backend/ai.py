import cv2
import numpy as np
import os
from collections import Counter
from keras.models import load_model
from keras.applications.resnet50 import preprocess_input
from moviepy import VideoFileClip
import config as cfg
from audio_ai import AudioEngine
from text_ai import TextEngine # <--- IMPORT NEW ENGINE

class ClinicalEngine:
    def __init__(self):
        print("[System] Initializing Multimodal Engines...")
        # 1. Load Face Model
        self.face_model = load_model(cfg.MODEL_PATH)
        self.face_cascade = cv2.CascadeClassifier(cfg.FACE_CASCADE_PATH)
        self.face_labels = ['Angry', 'Disgust', 'Fear', 'Happy', 'Neutral', 'Sad', 'Surprise']
        
        # 2. Load Audio & Text Models
        self.audio_engine = AudioEngine()
        self.text_engine = TextEngine() # <--- INIT TEXT
        print("[System] All Engines Ready.")

    def analyze_multimodal(self, video_path):
        """ Main entry point: Processes Video, Audio, & Text """
        
        # --- PREP: EXTRACT AUDIO ---
        temp_audio = "temp_fusion.wav"
        duration = 0
        try:
            clip = VideoFileClip(video_path)
            clip.audio.write_audiofile(temp_audio, logger=None)
            duration = clip.duration
            clip.close()
        except Exception as e:
            print(f"Audio Extraction Failed: {e}")
            return None

        # --- STEP 1: TEXT ANALYSIS (Global Context) ---
        print("[1/3] Processing Text (Speech -> Translate -> DeBERTa)...")
        text_content = self.text_engine.transcribe_and_translate(temp_audio)
        text_probs = self.text_engine.analyze_text(text_content) # Single Vector for whole session
        
        # --- STEP 2: AUDIO ANALYSIS (Timeline) ---
        print("[2/3] Processing Audio Stream...")
        audio_timeline = self.audio_engine.analyze_audio_timeline(temp_audio)
        
        # Cleanup audio file
        if os.path.exists(temp_audio): os.remove(temp_audio)

        # --- STEP 3: VIDEO ANALYSIS (Timeline) ---
        print("[3/3] Processing Video Stream...")
        visual_timeline_probs = self._process_visual_buckets(video_path, duration)

        # --- STEP 4: TRI-MODAL FUSION ---
        print("Fusing Modalities (Dynamic Weighted Logic)...")
        final_results = self._fuse_modalities(visual_timeline_probs, audio_timeline, text_probs)
        
        return final_results

    def _process_visual_buckets(self, video_path, duration):
        """ (Same as your previous code, scanning video buckets) """
        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS) or 30
        num_buckets = int(duration // 3.0) 
        buckets = [[] for _ in range(num_buckets)]
        
        frame_idx = 0
        while True:
            success, frame = cap.read()
            if not success: break
            
            if frame_idx % 5 == 0: 
                timestamp = frame_idx / fps
                bucket_idx = int(timestamp // 3.0)
                
                if bucket_idx < num_buckets:
                    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                    faces = self.face_cascade.detectMultiScale(gray, 1.1, 4)
                    
                    if len(faces) > 0:
                        x, y, w, h = max(faces, key=lambda b: b[2]*b[3])
                        face_img = cv2.resize(cv2.cvtColor(frame[y:y+h, x:x+w], cv2.COLOR_BGR2RGB), (224, 224))
                        
                        img_batch = np.expand_dims(face_img.astype('float32'), axis=0)
                        processed = preprocess_input(img_batch)
                        preds = self.face_model.predict(processed, verbose=0)[0]
                        buckets[bucket_idx].append(preds)
            
            frame_idx += 1
        cap.release()
        
        timeline_probs = []
        for i, b_preds in enumerate(buckets):
            if len(b_preds) > 0:
                avg_preds = np.mean(b_preds, axis=0) 
                prob_dict = {label: float(score) for label, score in zip(self.face_labels, avg_preds)}
            else:
                prob_dict = None
            
            timeline_probs.append({
                "start_time": i * 3,
                "end_time": (i+1) * 3,
                "probs": prob_dict
            })
            
        return timeline_probs

    # In ai.py

    def _fuse_modalities(self, visual, audio, text_probs):
        """ 
        Dynamic Fusion with Detailed Auditing
        """
        fused_timeline = []
        all_emotions = [] 
        
        # We process the minimum length available across timelines
        safe_len = min(len(visual), len(audio))
        
        print("\n" + "="*60)
        print(f"{'TIME':<8} | {'FACE':<15} | {'VOICE':<15} | {'TEXT':<15} | {'FINAL':<10}")
        print("="*60)

        for i in range(safe_len):
            time_str = f"{i*3}-{(i+1)*3}s"
            
            # 1. GET RAW DATA
            v_probs = visual[i]['probs'] # Face Dict
            a_probs = audio[i]['probs'] # Voice Dict
            t_probs = text_probs        # Text Dict (Global)
            
            # 2. IDENTIFY WINNERS FOR THIS SLICE (For your manual analysis)
            # Face
            if v_probs:
                face_win = max(v_probs, key=v_probs.get)
                face_conf = v_probs[face_win]
                face_desc = f"{face_win} ({int(face_conf*100)}%)"
            else:
                face_desc = "None"
            
            # Voice
            if a_probs:
                voice_win = max(a_probs, key=a_probs.get)
                voice_conf = a_probs[voice_win]
                voice_desc = f"{voice_win} ({int(voice_conf*100)}%)"
            else:
                voice_desc = "None"

            # Text (Context)
            if t_probs:
                text_win = max(t_probs, key=t_probs.get)
                text_conf = t_probs[text_win]
                text_desc = f"{text_win} ({int(text_conf*100)}%)"
            else:
                text_desc = "None"

            # 3. APPLY YOUR FUSION LOGIC
            fused_probs = {}
            
            if v_probs:
                # CHECK: Face Override for 'Angry'
                face_dominant = max(v_probs, key=v_probs.get)
                if face_dominant == 'Angry':
                    w_face, w_audio, w_text = 0.90, 0.05, 0.05
                else:
                    w_face, w_audio, w_text = 0.40, 0.30, 0.30

                for label in self.face_labels:
                    s_face = v_probs.get(label, 0.0)
                    s_audio = a_probs.get(label, 0.0) if a_probs else 0.0
                    s_text = t_probs.get(label, 0.0) if t_probs else 0.0
                    fused_probs[label] = (s_face * w_face) + (s_audio * w_audio) + (s_text * w_text)

            elif a_probs:
                # Fallback: Audio + Text
                for label in self.face_labels:
                    s_audio = a_probs.get(label, 0.0)
                    s_text = t_probs.get(label, 0.0) if t_probs else 0.0
                    fused_probs[label] = (s_audio * 0.7) + (s_text * 0.3)
            else:
                # No data
                print(f"{time_str:<8} | {'No Data':<15} | {'No Data':<15} | {'No Data':<15} | {'-'}")
                continue
                
            # 4. DETERMINE FINAL WINNER
            final_winner = max(fused_probs, key=fused_probs.get)
            final_conf = fused_probs[final_winner]
            
            # 5. LOG ROW TO CONSOLE (This is what you asked for)
            print(f"{time_str:<8} | {face_desc:<15} | {voice_desc:<15} | {text_desc:<15} | {final_winner}")

            # 6. SAVE TO TIMELINE
            fused_timeline.append({
                "time": time_str,
                "emotion": final_winner,
                "conf": round(final_conf * 100, 1),
                # We add the breakdown here too so you can access it in Flutter if needed
                "breakdown": {
                    "face": face_desc,
                    "voice": voice_desc,
                    "text": text_desc
                }
            })
            all_emotions.append(final_winner)
            
        print("="*60 + "\n")
            
        if not all_emotions: return None
        
        counts = Counter(all_emotions)
        total = len(all_emotions)
        stats = {k: round((v/total)*100, 1) for k, v in counts.items()}
        
        return {"stats": stats, "timeline": fused_timeline}