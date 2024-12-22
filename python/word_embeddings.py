from flask import Flask, request, jsonify
from flask_cors import CORS
import gensim
import random
import sys
from pathlib import Path
import unicodedata
import requests
import os
import firebase_admin
from firebase_admin import credentials, firestore
from apscheduler.schedulers.background import BackgroundScheduler
import time

app = Flask(__name__)
CORS(app)

# Initialize Firebase Admin
cred = credentials.Certificate('path/to/your/firebase-credentials.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# Constants
WORD_DURATION = 60  # seconds
COLLECTION = 'game'
DOCUMENT = 'currentWord'

def update_word():
    """Update the word in Firestore"""
    try:
        # Get a random word from the model
        word = random.choice(list(model.key_to_index.keys()))
        
        # Update Firestore
        db.collection(COLLECTION).document(DOCUMENT).set({
            'word': word,
            'timestamp': int(time.time() * 1000)  # Current time in milliseconds
        })
        
        print(f"Word updated successfully to: {word}")
    except Exception as e:
        print(f"Error updating word: {str(e)}")

# Initialize the scheduler
scheduler = BackgroundScheduler()
scheduler.add_job(
    update_word, 
    'interval', 
    seconds=WORD_DURATION,
    id='update_word_job'
)

# Start the scheduler when the app starts
@app.before_first_request
def init_scheduler():
    scheduler.start()

# Add a route to manually trigger word update (for testing)
@app.route('/update-word', methods=['POST'])
def trigger_word_update():
    try:
        update_word()
        return jsonify({
            'success': True,
            'message': 'Word updated successfully'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

FILE_ID = "1ni-nwcVhNq7kJxX_Whv3PxknEqrIGMBK"
MODEL_PATH = "model.bin"

def download_model():
    """Download the model from Google Drive if it doesn't exist"""
    if not Path(MODEL_PATH).exists():
        try:
            session = requests.Session()
            url = f"https://drive.google.com/uc?export=download&id={FILE_ID}"
            response = session.get(url, stream=True)
            
            token = None
            for key, value in response.cookies.items():
                if key.startswith('download_warning'):
                    token = value
                    break

            if token:
                url = f"{url}&confirm={token}"
            
            response = session.get(url, stream=True)
            response.raise_for_status()
            
            with open(MODEL_PATH, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
            
            print("Model downloaded successfully")
        except Exception as e:
            print(f"Error downloading model: {str(e)}")
            if Path(MODEL_PATH).exists():
                Path(MODEL_PATH).unlink()
            raise

def get_model_path():
    """Get the path to the model file"""
    return MODEL_PATH

download_model()

try:
    model_path = get_model_path()
    
    model = gensim.models.KeyedVectors.load_word2vec_format(
        model_path, 
        binary=True, 
        unicode_errors='ignore'
    )
    
except Exception as e:
    import traceback
    traceback.print_exc()
    sys.exit(1)

@app.route('/embed', methods=['POST'])
def get_embedding():
    try:
        data = request.get_json()
        received_word = data.get('text', '')
        
        embedding = model[received_word].tolist()
        return jsonify({
            'success': True,
            'embedding': embedding
        })
    except KeyError:
        return jsonify({
            'success': False,
            'error': f"Word '{data.get('text', '')}' not found in vocabulary"
        }), 404
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/similar', methods=['POST'])
def get_similar_words():
    try:
        data = request.get_json()
        word = data.get('text', '')
        topn = data.get('topn', 100)
        
        similar_words = model.most_similar(word, topn=topn)
        result = [{"word": word, "similarity": float(score)} for word, score in similar_words]
        
        return jsonify({
            'success': True,
            'similar_words': result
        })
    except KeyError:
        return jsonify({
            'success': False,
            'error': f"Word '{data.get('text', '')}' not found in vocabulary"
        }), 404
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/random', methods=['GET'])
def get_random_word():
    try:
        word = random.choice(list(model.key_to_index.keys()))
        return jsonify({
            'success': True,
            'word': word
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/similarity', methods=['POST'])
def get_similarity():
    try:
        data = request.get_json()
        word1 = data.get('word1', '')
        word2 = data.get('word2', '')
        
        similarity = model.similarity(word1, word2)
        return jsonify({
            'success': True,
            'similarity': float(similarity)
        })
    except KeyError as e:
        return jsonify({
            'success': False,
            'error': f"Word not found in vocabulary"
        }), 404
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'model_loaded': model is not None
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)