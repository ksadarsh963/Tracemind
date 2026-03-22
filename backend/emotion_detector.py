# emotion_detector.py
import cv2
import numpy as np
import os
import keras # <--- Fixes Pylance Error
from keras.models import load_model
from keras.applications.resnet50 import preprocess_input # <--- Correct Import

class FacialEmotionAnalyzer:
    def __init__(self, model_path='face_model_legacy.h5'):
        abs_path = os.path.abspath(model_path)
        if not os.path.exists(abs_path):
            raise FileNotFoundError(f"Model not found at {abs_path}")
            
        print(f"Loading Facial Model from {abs_path}...")
        self.model = load_model(abs_path)
        self.labels = ['Angry', 'Disgust', 'Fear', 'Happy', 'Neutral', 'Sad', 'Surprise']
        print("Model Loaded.")

    def preprocess_batch(self, faces_list):
        """
        Takes a list of cropped face images (RGB) and prepares them for ResNet.
        """
        if len(faces_list) == 0:
            return np.array([])

        # 1. Convert list to Numpy Array
        faces_array = np.array(faces_list)

        # 2. Ensure Float32
        faces_array = faces_array.astype('float32')

        # 3. Apply ResNet Preprocessing (Mean Subtraction)
        #    CRITICAL: This replaces the /255.0 normalization
        faces_preprocessed = preprocess_input(faces_array)
        
        return faces_preprocessed

    def predict_batch(self, preprocessed_faces):
        """
        Runs prediction on the whole batch at once (Faster than loop)
        """
        if len(preprocessed_faces) == 0:
            return []

        predictions = self.model.predict(preprocessed_faces, verbose=0)
        return predictions