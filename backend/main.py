import os
import datetime
from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, firestore, storage
import config as cfg
from ai import ClinicalEngine
from pdf_generator import create_pdf

# --- 1. FIREBASE SETUP (Verified Configuration) ---
if not firebase_admin._apps:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred, {
        'storageBucket': 'tracemind-2682c.firebasestorage.app' 
    })

# Initialize Clients GLOBALLY
db = firestore.client()
bucket = storage.bucket()

app = Flask(__name__)

# Initialize AI once at startup
engine = ClinicalEngine()

@app.route('/analyze', methods=['POST'])
def analyze_video():
    # 1. Check for Video
    if 'video' not in request.files:
        return jsonify({"status": "error", "message": "No video file provided"}), 400
    
    # 2. Get User ID (The Doctor)
    user_id = request.form.get('user_id', 'unknown_doctor')

    # 3. Save Video Temporarily
    file = request.files['video']
    temp_path = "temp_upload.mp4"
    file.save(temp_path)
    
    # 4. Receive Patient Data
    patient_data = {
        "name": request.form.get("name", "Unknown Patient"),
        "id": request.form.get("id", "TM-000"),
        "age": request.form.get("age", "N/A"),
        "gender": request.form.get("gender", "N/A"),
        "date": request.form.get("date", datetime.datetime.now().strftime("%Y-%m-%d")),
        "notes": request.form.get("notes", "No clinical notes provided.")
    }

    print(f"Received Request: {patient_data['name']} (Doc ID: {user_id})")

    try:
        # 5. Analyze Video (AI)
        results = engine.analyze_multimodal(temp_path)
        
        if not results:
            return jsonify({"status": "error", "message": "No face or voice detected"}), 500

        # --- FIX: Calculate Dominant Emotion if missing to prevent KeyError ---
        if 'dominant_emotion' not in results:
            stats = results.get('stats', {})
            if stats:
                # Identify the highest scoring emotion
                dominant_emotion = max(stats, key=stats.get)
                confidence = stats[dominant_emotion]
            else:
                dominant_emotion = "Neutral"
                confidence = 0
            
            # Injecting keys back into the result dictionary
            results['dominant_emotion'] = dominant_emotion
            results['confidence'] = confidence
        # ---------------------------------------------------------------------

        # 6. Generate PDF Report
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        pdf_name = f"{patient_data['id']}_{timestamp}_Report.pdf"
        
        if not os.path.exists(cfg.REPORT_FOLDER):
            os.makedirs(cfg.REPORT_FOLDER)
            
        pdf_path = os.path.join(cfg.REPORT_FOLDER, pdf_name)
        create_pdf(patient_data, results, pdf_path)
        
        # 7. Upload PDF to Firebase Storage
        print(f"☁️ Uploading {pdf_name} to Cloud...")
        blob = bucket.blob(f"reports/{pdf_name}")
        blob.upload_from_filename(pdf_path)
        
        # Generate a download URL (Valid for 1 year)
        pdf_url = blob.generate_signed_url(expiration=datetime.timedelta(days=365))
        
        # 8. SAVE TO DATABASE (Firestore Activity Log)
        doc_ref = db.collection('activity_log').document()
        doc_ref.set({
            'doctor_id': user_id,
            'type': 'session',
            'message': f"Analysis: {results['dominant_emotion']}", 
            'emotion': results['dominant_emotion'],
            'confidence': results['confidence'],
            'pdf_url': pdf_url,
            'timestamp': datetime.datetime.now()
        })
        print("✅ Database Updated Successfully!")

        # 9. Return Result to App
        return jsonify({
            "status": "success",
            "stats": results['stats'],
            "timeline": results['timeline'],
            "pdf_url": pdf_url 
        })

    except Exception as e:
        print(f"❌ Server Error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        # Cleanup temp video
        if os.path.exists(temp_path):
            os.remove(temp_path)

@app.route('/register', methods=['POST'])
def register_user():
    try:
        # 1. Grab the JSON data sent from the Flutter app
        data = request.json
        
        # Log it to the terminal so you can see what Flutter is sending
        print(f"📥 Registration Request Received: {data}")

        # 2. Extract the user details (adjust these keys based on what Flutter sends)
        email = data.get('email')
        uid = data.get('uid')
        name = data.get('name')

        if not email or not uid:
            return jsonify({"status": "error", "message": "Missing email or UID"}), 400

        # 3. Save the new doctor/user to your Firestore Database
        doc_ref = db.collection('users').document(uid)
        doc_ref.set({
            'name': name,
            'email': email,
            'role': 'doctor',
            'created_at': datetime.datetime.now()
        })
        print(f"✅ User {email} saved to database!")

        # 4. Return success back to the Flutter app!
        return jsonify({"status": "success", "message": "Registration complete"}), 200

    except Exception as e:
        print(f"❌ Registration Error: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/health')
def health():
    return jsonify({"status": "ok", "message": "Tracemind is running"}), 200

if __name__ == '__main__':
    # Ensuring the host is set to 0.0.0.0 to allow mobile connections
    app.run(host='0.0.0.0', port=5000, debug=True)