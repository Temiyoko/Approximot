from flask import Flask, request, jsonify, redirect
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
from apscheduler.triggers.cron import CronTrigger
from datetime import datetime
import pytz
from threading import Lock

app = Flask(__name__)
CORS(app)

if 'FIREBASE_CREDENTIALS' in os.environ:
    cred_dict = json.loads(os.environ.get('FIREBASE_CREDENTIALS'))
    cred = credentials.Certificate(cred_dict)
else:
    cred = credentials.Certificate('firebase-credentials.json')

firebase_admin.initialize_app(cred)
db = firestore.client()

COLLECTION = 'game'
DOCUMENT = 'currentWord'
WORD_LIST_FILE_ID = "1VAkmMXs83XdOky0_LTMq2C1qjvPya7Wu"
FILE_ID = "1YcA6pB5Y138X0Chk66fv_eYKGLzW0N2c"
MODEL_PATH = "model.bin"
timezone = 'Europe/Paris'

# Add application state management
class ApplicationState:
    def __init__(self):
        self.model = None
        self.cached_word = None
        self.cached_timestamp = 0
        self.update_lock = Lock()
        self.initialized = False

app_state = ApplicationState()

def update_word():
    """Update the word in Firestore"""
    if not app_state.update_lock.acquire(blocking=False):
        print("Update already in progress, skipping...")
        return
        
    try:
        french_tz = pytz.timezone(timezone)
        current_time = int(datetime.now(french_tz).timestamp() * 1000)
        
        # Check if we're exactly at a 30-minute mark in French time
        current_dt = datetime.fromtimestamp(current_time / 1000, french_tz)
        minutes = current_dt.minute
        
        if minutes not in [0, 30]:
            print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Skipping update - not at 30-minute mark")
            return

        current_word_doc = db.collection(COLLECTION).document(DOCUMENT).get()

        if current_word_doc.exists:
            current_word_data = current_word_doc.to_dict()
            old_word = current_word_data.get('word')
            old_word_date = current_word_data.get('timestamp')
            found_count = current_word_data.get('found_count', 0)
            
            # Prevent multiple updates in the same minute
            if old_word_date and (current_time - old_word_date < 60000):
                print("Word update skipped - too soon since last update")
                return

        last_words_doc = db.collection('game').document('last_words').get()
        if last_words_doc.exists:
            last_words_list = last_words_doc.to_dict().get('last_words', [])
        else:
            last_words_list = []

        if not last_words_list or last_words_list[-1]['timestamp'] != old_word_date:
            last_words_list.append({
                'word': old_word,
                'timestamp': old_word_date,
                'found_count': found_count
            })

        if len(last_words_list) > 100:
            last_words_list.pop(0)

        db.collection('game').document('last_words').set({
            'last_words': last_words_list
        })

        words = load_word_list()
        if not words:
            print("Error: Word list is empty.")
            return

        word = random.choice(words)

        batch = db.batch()
        for user in db.collection('users').stream():
            batch.set(db.collection('users').document(user.id), {
                'lexitomGuesses': [],
                'wikitomGuesses': []
            }, merge=True)
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

        app_state.cached_word = word
        app_state.cached_timestamp = current_time

        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Word updated successfully to: {word}")
    except Exception as e:
        print(f"Error updating word: {str(e)}")
    finally:
        app_state.update_lock.release()

scheduler = BackgroundScheduler(timezone=timezone)
scheduler.add_job(
    update_word,
    CronTrigger(minute='0,30', timezone=timezone),
    id='update_word_job'
)

@app.before_first_request
def init_scheduler():
    if app_state.initialized:
        return
        
    if not scheduler.running:
        scheduler.start()
    download_model()
    download_word_list()
    load_model()
    update_word()
    app_state.initialized = True

@app.before_request
def remove_double_slash():
    if '//' in request.path:
        path = request.path.replace('//', '/')
        return redirect(path, code=301)

def get_download_url(session, base_url):
    """Get the final download URL handling Google Drive confirmation token"""
    response = session.get(base_url, stream=True)

    for key, value in response.cookies.items():
        if key.startswith('download_warning'):
            return f"{base_url}&confirm={value}"

    return base_url

def save_model_file(response):
    """Save the model file from the response stream"""
    with open(MODEL_PATH, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            if chunk:
                f.write(chunk)

def download_model():
    """Download the model from Google Drive if it doesn't exist"""
    if Path(MODEL_PATH).exists():
        return
    try:
        session = requests.Session()
        base_url = f"https://drive.google.com/uc?export=download&id={FILE_ID}"
        final_url = get_download_url(session, base_url)
        response = session.get(final_url, stream=True)
        response.raise_for_status()

        save_model_file(response)
        print("Model downloaded successfully")

    except Exception as e:
        print(f"Error downloading model: {str(e)}")
        if Path(MODEL_PATH).exists():
            Path(MODEL_PATH).unlink()
        raise

def load_model():
    """Load the model from the specified path"""
    if app_state.model is not None:
        return
        
    try:
        model_path = get_model_path()
        app_state.model = gensim.models.KeyedVectors.load_word2vec_format(
            model_path,
            binary=True,
            unicode_errors='ignore'
        )
        print("Model loaded successfully")
    except Exception as e:
        print(f"An unexpected error occurred: {str(e)}")
        sys.exit(1)

def download_word_list():
    """Download the word list from Google Drive"""
    word_list_path = "motscommuns.txt"
    if not Path(word_list_path).exists():
        try:
            session = requests.Session()
            url = f"https://drive.google.com/uc?export=download&id={WORD_LIST_FILE_ID}"
            response = session.get(url)
            response.raise_for_status()

            with open(word_list_path, 'wb') as f:
                f.write(response.content)

            print("Word list downloaded successfully")
        except Exception as e:
            print(f"Error downloading word list: {str(e)}")
            if Path(word_list_path).exists():
                Path(word_list_path).unlink()
            raise

def load_word_list():
    """Load the word list from the specified path"""
    with open("motscommuns.txt", 'r') as f:
        words = f.read().splitlines()
    return words

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

def get_model_path():
    """Get the path to the model file"""
    return MODEL_PATH

@app.route('/embed', methods=['POST'])
def get_embedding():
    data = request.get_json()
    try:
        received_word = data.get('text', '')

        embedding = app_state.model[received_word].tolist()
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
    data = request.get_json()
    try:
        word = data.get('text', '')
        topn = data.get('topn', 100)

        similar_words = app_state.model.most_similar(word, topn=topn)
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
        word = random.choice(list(app_state.model.key_to_index.keys()))
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

        similarity = app_state.model.similarity(word1, word2)
        return jsonify({
            'success': True,
            'similarity': float(similarity)
        })
    except KeyError as _:
        return jsonify({
            'success': False,
            'error': "Word not found in vocabulary"
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
        'model_loaded': app_state.model is not None
    })

@app.route('/current-word', methods=['GET'])
def get_current_word():
    try:
        # Get time in French timezone
        french_tz = pytz.timezone(timezone)
        current_time = int(datetime.now(french_tz).timestamp() * 1000)
        
        # Get the document first
        doc = db.collection(COLLECTION).document(DOCUMENT).get()
        if not doc.exists:
            return jsonify({
                'success': False,
                'error': 'No word found'
            }), 404

        data = doc.to_dict()
        word = data.get('word')
        timestamp = data.get('timestamp', 0)
        found_count = data.get('found_count', 0)

        # Update cache
        app_state.cached_word = word
        app_state.cached_timestamp = timestamp

        # Calculate next update time
        current_dt = datetime.fromtimestamp(current_time / 1000, french_tz)
        current_minute = current_dt.minute
        current_hour = current_dt.hour

        if current_minute < 30:
            next_update_minute = 30
            next_update_hour = current_hour
        else:
            next_update_minute = 0
            next_update_hour = (current_hour + 1) % 24

        next_dt = current_dt.replace(hour=next_update_hour, minute=next_update_minute, second=0, microsecond=0)
        next_update_time = int(next_dt.timestamp() * 1000)
        remaining_time = next_update_time - current_time

        return jsonify({
            'success': True,
            'word': word,
            'timestamp': timestamp,
            'current_time': current_time,
            'time_remaining': remaining_time,
            'found_count': found_count
        })
    except Exception as e:
        print(f"Error in get_current_word: {str(e)}")
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

        current_data = doc.to_dict()
        current_found_count = current_data.get('found_count', 0)
        new_found_count = current_found_count + 1

        doc_ref.update({
            'found_count': new_found_count
        })

        return jsonify({
            'success': True
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/choose-word', methods=['POST'])
def choose_word():
    """Choose a specific word to guess and reset the timer and states."""
    try:
        data = request.get_json()
        chosen_word = data.get('word', '').strip()

        if not chosen_word:
            return jsonify({
                'success': False,
                'error': 'No word provided'
            }), 400

        current_time = int(time.time() * 1000)

        db.collection(COLLECTION).document(DOCUMENT).set({
            'word': chosen_word,
            'timestamp': current_time,
            'found_count': 0
        })

        batch = db.batch()
        for user in db.collection('users').stream():
            batch.set(db.collection('users').document(user.id), {
                'lexitomGuesses': [],
                'wikitomGuesses': []
            }, merge=True)
        for game in db.collection('game_sessions').stream():
            batch.update(db.collection('game_sessions').document(game.id), {
                'playerGuesses': {},
                'wordFound': False,
                'winners': []
            })
        batch.commit()

        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Word chosen successfully: {chosen_word}")

        app_state.cached_word = chosen_word
        app_state.cached_timestamp = current_time

        return jsonify({
            'success': True,
            'message': f'Word chosen successfully: {chosen_word}'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)