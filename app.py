from flask import Flask, request, jsonify
from flask_cors import CORS
import psycopg2
import os
from flask import jsonify, json


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
    rows = cur.fetchall()
    cur.close()
    conn.close()

    grouped = {'plans': [], 'tasks': [], 'docs': []}
    for name, section in rows:
        if section in grouped:
            grouped[section].append(name)
    return jsonify(grouped)


@app.route('/files/delete', methods=['POST'])
def delete_file():
    data = request.get_json()
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM files WHERE topic_id = %s AND name = %s", (data['topic_id'], data['name']))
    conn.commit()
    cur.close()
    conn.close()
    return '', 200


@app.route('/files/add', methods=['POST'])
def add_file():
    data = request.get_json()
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO files (topic_id, section, name, linked, content)
        VALUES (%s, %s, %s, FALSE, '[]')
    """, (data['topic_id'], data['section'], data['name']))
    conn.commit()
    cur.close()
    conn.close()
    return '', 200


# ----------FILES CONTENT ----------
@app.route('/file_content', methods=['POST'])
def save_file_content():
    data = request.get_json()
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        UPDATE files
        SET content = %s
        WHERE topic_id = %s AND name = %s
    """, (json.dumps(data['content']), data['topic_id'], data['name']))
    conn.commit()
    cur.close()
    conn.close()
    return '', 200

@app.route('/file_link/toggle', methods=['POST'])
def toggle_file_link():
    data = request.get_json()
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        UPDATE files
        SET linked = NOT linked
        WHERE topic_id = %s AND name = %s
    """, (data['topic_id'], data['name']))
    conn.commit()
    cur.close()
    conn.close()
    return '', 200


@app.route('/file_info', methods=['GET'])
def get_file_info():
    topic_id = request.args.get('topic_id')
    file_name = request.args.get('file_name')

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT content, linked FROM files
        WHERE topic_id = %s AND name = %s
    """, (topic_id, file_name))
    row = cur.fetchone()
    cur.close()
    conn.close()

    if row:
        return jsonify({'content': row[0], 'linked': row[1]})
    else:
        return jsonify({'error': 'File not found'}), 404


# ---------- LISTS OF FILES ----------
@app.route('/link_file', methods=['POST'])
def link_file():
    data = request.get_json()
    file_id = data.get('file_id')
    if not file_id:
        return jsonify({'error': 'file_id missing'}), 400

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("UPDATE files SET linked = TRUE WHERE id = %s", (file_id,))
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({'status': 'linked'})

@app.route('/unlink_file', methods=['POST'])
def unlink_file():
    data = request.get_json()
    file_id = data.get('file_id')
    if not file_id:
        return jsonify({'error': 'file_id missing'}), 400

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("UPDATE files SET linked = FALSE WHERE id = %s", (file_id,))
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({'status': 'unlinked'})

@app.route('/linked_files', methods=['GET'])
def get_linked_files():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT f.id, f.name, f.section, t.name, t.color
        FROM files f
        JOIN topics t ON f.topic_id = t.id
        WHERE f.linked = TRUE
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()

    result = [
        {
            'id': row[0],
            'name': row[1],
            'section': row[2],
            'topic_name': row[3],
            'color': row[4]
        }
        for row in rows
    ]
    return jsonify(result)

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
