from flask import Flask, request, jsonify
from flask_cors import CORS
import gensim
import random
import sys
from pathlib import Path
import requests
import os
import firebase_admin
from firebase_admin import credentials, firestore
from apscheduler.schedulers.background import BackgroundScheduler
import time
import json

app = Flask(__name__)
CORS(app)

if 'FIREBASE_CREDENTIALS' in os.environ:
    cred_dict = json.loads(os.environ.get('FIREBASE_CREDENTIALS'))
    cred = credentials.Certificate(cred_dict)
else:
    cred = credentials.Certificate('firebase-credentials.json')

firebase_admin.initialize_app(cred)
db = firestore.client()

WORD_DURATION = 300  # seconds
COLLECTION = 'game'
DOCUMENT = 'currentWord'

last_words = []

cached_word = None
cached_timestamp = 0

def update_word():
    """Update the word in Firestore"""
    try:
        current_time = int(time.time() * 1000)
        current_word_doc = db.collection(COLLECTION).document(DOCUMENT).get()

        if current_word_doc.exists:
            current_word_data = current_word_doc.to_dict()
            old_word = current_word_data.get('word')
            old_word_date = current_word_data.get('timestamp')
            found_count = current_word_data.get('found_count', 0) if current_word_doc.exists else 0
        else:
            old_word = None
            old_word_date = None

        word = random.choice(list(model.key_to_index.keys()))

        last_words.append({
            'word': old_word,
            'timestamp': old_word_date,
            'found_count': found_count
        })

        db.collection('game').document('last_words').set({
            'last_words': last_words
        })

        batch = db.batch()
        for user in db.collection('users').stream():
            batch.update(db.collection('users').document(user.id), {'singlePlayerGuesses': []})
        for game in db.collection('game_sessions').stream():
            batch.update(db.collection('game_sessions').document(game.id), {
                'playerGuesses': {},
                'wordFound': False,
                'winners': []
            })
        batch.commit()

        db.collection(COLLECTION).document(DOCUMENT).set({
            'word': word,
            'timestamp': current_time,
            'found_count': 0
        })

        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Word updated successfully to: {word}")
    except Exception as e:
        print(f"Error updating word: {str(e)}")

scheduler = BackgroundScheduler()
scheduler.add_job(update_word, 'interval', seconds=WORD_DURATION, id='update_word_job')

@app.before_first_request
def init_scheduler():
    scheduler.start()
    download_model()
    load_model()
    update_word()

@app.route('/force-update-word', methods=['POST'])
def force_update_word():
    """Force an immediate word update"""
    update_word()
    return jsonify({
        'success': True,
        'message': 'Word updated successfully'
    })

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

def load_model():
    """Load the model from the specified path"""
    try:
        model_path = get_model_path()
        global model
        model = gensim.models.KeyedVectors.load_word2vec_format(
            model_path,
            binary=True,
            unicode_errors='ignore'
        )
        print("Model loaded successfully")
    except Exception as e:
        import traceback
        traceback.print_exc()
        sys.exit(1)

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

FILE_ID = "1YcA6pB5Y138X0Chk66fv_eYKGLzW0N2c"
MODEL_PATH = "model.bin"

def get_model_path():
    """Get the path to the model file"""
    return MODEL_PATH

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

@app.route('/current-word', methods=['GET'])
def get_current_word():
    global cached_word, cached_timestamp
    try:
        current_time = int(time.time() * 1000)

        if cached_word and (current_time - cached_timestamp < WORD_DURATION * 1000):
            doc = db.collection(COLLECTION).document(DOCUMENT).get()
            found_count = doc.to_dict().get('found_count', 0)
            remaining_time = (WORD_DURATION * 1000) - (current_time - cached_timestamp)
            remaining_time = max(0, remaining_time)
            return jsonify({
                'success': True,
                'word': cached_word,
                'timestamp': cached_timestamp,
                'current_time': current_time,
                'time_remaining': remaining_time,
                'found_count': found_count
            })

        doc = db.collection(COLLECTION).document(DOCUMENT).get()
        if not doc.exists:
            return jsonify({
                'success': False,
                'error': 'No word found'
            }), 404

        data = doc.to_dict()
        timestamp = data.get('timestamp', 0)
        found_count = data.get('found_count', 0)

        cached_word = data.get('word')
        cached_timestamp = timestamp

        remaining_time = (WORD_DURATION * 1000) - (current_time - cached_timestamp)
        remaining_time = max(0, remaining_time)

        return jsonify({
            'success': True,
            'word': cached_word,
            'timestamp': cached_timestamp,
            'current_time': current_time,
            'time_remaining': remaining_time,
            'found_count': found_count
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/increment-found-count', methods=['POST'])
def increment_found_count():
    try:
        doc_ref = db.collection(COLLECTION).document(DOCUMENT)
        doc = doc_ref.get()

        if not doc.exists:
            return jsonify({
                'success': False,
                'error': 'No word found'
            }), 404

        doc_ref.update({
            'found_count': firestore.Increment(1)
        })

        return jsonify({
            'success': True
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)