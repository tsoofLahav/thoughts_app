from flask import Flask, request, jsonify
from flask_cors import CORS
import psycopg2
import os
from flask import jsonify


app = Flask(__name__)
CORS(app)
def get_db_connection():
    return psycopg2.connect(
        host=os.environ['DB_HOST'],
        database=os.environ['DB_NAME'],
        user=os.environ['DB_USER'],
        password=os.environ['DB_PASSWORD']
    )

@app.route('/ping')
def ping():
    return 'pong', 200

# ---------- TOPICS ----------
# GET all topics organized by houses
@app.route('/directories', methods=['GET'])
def get_directories():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, house, name, color FROM topics")
    rows = cur.fetchall()
    cur.close()
    conn.close()

    houses = {}
    for topic_id, house, name, color in rows:
        houses.setdefault(house, []).append({
            'id': topic_id,
            'name': name,
            'color': color
        })
    return jsonify(houses)

# POST and replace all directories
@app.route('/directories', methods=['POST'])
def save_directories():
    data = request.get_json()
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("DELETE FROM topics")  # wipe old
    for house, topics in data.items():
        for topic in topics:
            cur.execute(
                "INSERT INTO topics (house, name, color) VALUES (%s, %s, %s)",
                (house, topic['name'], topic['color'])
            )

    conn.commit()
    cur.close()
    conn.close()
    return jsonify({'status': 'saved'})

# ---------- FILES ----------
@app.route('/files/<int:topic_id>', methods=['GET'])
def get_files(topic_id):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT name, section FROM files WHERE topic_id = %s", (topic_id,))
    grouped = {'plans': [], 'tasks': [], 'docs': []}
    for name, section in cur.fetchall():
        if section in grouped:
            grouped[section].append(name)
    cur.close()
    conn.close()
    return jsonify(grouped)

@app.route('/files', methods=['POST'])
def create_file():
    data = request.get_json()
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO files (topic_id, name, section)
        VALUES (%s, %s, %s) RETURNING id
    """, (data['topic_id'], data['name'], data['section']))
    file_id = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({'file_id': file_id})

# ---------- ENTRIES ----------
@app.route('/entries/<int:file_id>', methods=['GET'])
def get_entries(file_id):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, text, date, done FROM file_entries
        WHERE file_id = %s ORDER BY "order", id
    """, (file_id,))
    entries = [
        {'id': r[0], 'text': r[1], 'date': r[2], 'done': r[3]}
        for r in cur.fetchall()
    ]
    cur.close()
    conn.close()
    return jsonify(entries)

@app.route('/save_entry', methods=['POST'])
def save_entry():
    data = request.get_json()
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO file_entries (file_id, text, date, done, "order")
        VALUES (%s, %s, %s, %s, %s)
    """, (
        data['file_id'], data['text'], data.get('date'),
        data.get('done', False), data.get('order', 0)
    ))
    conn.commit()
    cur.close()
    conn.close()
    return {'status': 'entry saved'}

# ---------------- GREEN NOTE SYSTEM ----------------

# Save or update list of topics
@app.route('/green_note_topics', methods=['POST'])
def save_green_note_topics():
    data = request.get_json()
    topics = data.get('topics', [])
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM green_note_topics")
    for topic in topics:
        cur.execute("INSERT INTO green_note_topics (name) VALUES (%s)", (topic,))
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({'status': 'topics saved'})

# Get current topic list
@app.route('/green_note_topics', methods=['GET'])
def get_green_note_topics():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT name FROM green_note_topics")
    topics = [row[0] for row in cur.fetchall()]
    cur.close()
    conn.close()
    return jsonify(topics)

# Save or overwrite a green note version
@app.route('/green_notes', methods=['POST'])
def save_green_note():
    data = request.get_json()
    signature = data['signature']
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("DELETE FROM green_notes WHERE signature = %s", (signature,))
    cur.execute("""
        INSERT INTO green_notes (signature, date, good_1, good_2, good_3, improve)
        VALUES (%s, %s, %s, %s, %s, %s) RETURNING id
    """, (
        signature, data['date'], data['good_1'], data['good_2'],
        data['good_3'], data['improve']
    ))
    note_id = cur.fetchone()[0]

    cur.execute("DELETE FROM green_note_scores WHERE note_id = %s", (note_id,))
    for score in data['scores']:
        cur.execute("""
            INSERT INTO green_note_scores (note_id, category, score)
            VALUES (%s, %s, %s)
        """, (note_id, score['category'], score['score']))

    conn.commit()
    cur.close()
    conn.close()
    return jsonify({'status': 'note saved'})

# Get all note signatures (for determining latest version per day)
@app.route('/green_notes/signatures', methods=['GET'])
def get_all_green_note_signatures():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT signature FROM green_notes ORDER BY date, signature")
    signatures = [row[0] for row in cur.fetchall()]
    cur.close()
    conn.close()
    return jsonify(signatures)

# Get a note by its signature
@app.route('/green_notes/version/<signature>', methods=['GET'])
def get_green_note_by_signature(signature):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, date, good_1, good_2, good_3, improve
        FROM green_notes WHERE signature = %s
    """, (signature,))
    row = cur.fetchone()
    if not row:
        return jsonify(None)

    note_id = row[0]
    cur.execute("SELECT category, score FROM green_note_scores WHERE note_id = %s", (note_id,))
    scores = [{'category': r[0], 'score': r[1]} for r in cur.fetchall()]
    cur.close()
    conn.close()
    return jsonify({
        'signature': signature,
        'date': row[1],
        'good_1': row[2],
        'good_2': row[3],
        'good_3': row[4],
        'improve': row[5],
        'scores': scores
    })


@app.route('/green_notes/<signature>', methods=['DELETE'])
def delete_green_note(signature):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM green_note_scores WHERE note_id = (SELECT id FROM green_notes WHERE signature = %s)", (signature,))
    cur.execute("DELETE FROM green_notes WHERE signature = %s", (signature,))
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({'status': 'deleted'})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
