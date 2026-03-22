import os
import cv2

# --- PATHS ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# Face Model
MODEL_PATH = "C:/Users/USER/Desktop/Main Project/models/face_model_finetuned_FINAL.h5"
FACE_CASCADE_PATH = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
# Voice Model
AUDIO_MODEL_PATH = "voice_model_L4_legacy.h5"
LABEL_ENCODER_PATH = "label_encoder.pkl"

# --- REPORT SETTINGS ---
REPORT_FOLDER = os.path.join(BASE_DIR, "reports")
REPORT_FILENAME = "TraceMind_Clinical_Report.pdf"

