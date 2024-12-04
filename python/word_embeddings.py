from flask import Flask, request, jsonify
from flask_cors import CORS
import gensim
import random
import sys
from pathlib import Path
import unicodedata

app = Flask(__name__)
CORS(app)

def normalize_word(word):
    """Remove accents and convert to lowercase"""
    return ''.join(
        c for c in unicodedata.normalize('NFD', word.lower())
        if unicodedata.category(c) != 'Mn'
    )

def get_model_path():
    """Get the correct path to the model file regardless of how the script is run"""
    possible_paths = [
        Path('assets/models/model.bin'),
        Path(__file__).parent.parent / 'assets' / 'models' / 'model.bin',
        Path('/data/user/0/com.approximot.projet/app_flutter/models/model.bin'),
        Path.home() / 'path/to/your/project/assets/models/model.bin'
    ]

    for path in possible_paths:
        if path.is_file():
            return str(path)
    
    raise FileNotFoundError(f"Model file not found. Searched paths: {[str(p) for p in possible_paths]}")

try:
    model_path = get_model_path()
    model = gensim.models.KeyedVectors.load_word2vec_format(model_path, binary=True, unicode_errors='ignore')
except Exception as e:
    print(f"Failed to load model: {str(e)}")
    sys.exit(1)

@app.route('/embed', methods=['POST'])
def get_embedding():
    try:
        data = request.get_json()
        word = normalize_word(data.get('text', ''))
        
        embedding = model[word].tolist()
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
        word = normalize_word(data.get('text', ''))
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
        word1 = normalize_word(data.get('word1', ''))
        word2 = normalize_word(data.get('word2', ''))
        
        similarity = float(model.similarity(word1, word2))
        return jsonify({
            'success': True,
            'similarity': similarity
        })
    except KeyError:
        return jsonify({
            'success': False,
            'error': f"Word '{data.get('word1', '')}' not found in vocabulary"
        }), 404
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)