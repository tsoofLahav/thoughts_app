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

# ---------- TOPICS ----------
@app.route('/topics', methods=['GET'])
def get_topics():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, name, color FROM topics")
    topics = [{'id': r[0], 'name': r[1], 'color': r[2]} for r in cur.fetchall()]
    cur.close()
    conn.close()
    return jsonify(topics)

# ---------- FILES ----------
@app.route('/files/<int:topic_id>', methods=['GET'])
def get_files(topic_id):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, name, section FROM files WHERE topic_id = %s", (topic_id,))
    files = [{'id': r[0], 'name': r[1], 'section': r[2]} for r in cur.fetchall()]
    cur.close()
    conn.close()
    return jsonify(files)

@app.route('/create_file', methods=['POST'])
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

# ---------- GREEN NOTE ----------

@app.route('/green_notes', methods=['POST'])
def save_green_note():
    data = request.get_json()
    conn = get_db_connection()
    cur = conn.cursor()

    # Always insert a new note (new version)
    cur.execute("""
        INSERT INTO green_notes (date, good_1, good_2, good_3, improve, created_at)
        VALUES (%s, %s, %s, %s, %s, NOW()) RETURNING id
    """, (
        data['date'], data['good_1'], data['good_2'],
        data['good_3'], data['improve']
    ))
    note_id = cur.fetchone()[0]

    for score in data['scores']:
        cur.execute("""
            INSERT INTO green_note_scores (note_id, category, score)
            VALUES (%s, %s, %s)
        """, (note_id, score['category'], score['score']))

    conn.commit()
    cur.close()
    conn.close()
    return jsonify({'status': 'green note saved'})


@app.route('/green_notes/<date>', methods=['GET'])
def get_latest_note_by_date(date):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, good_1, good_2, good_3, improve
        FROM green_notes
        WHERE date = %s
        ORDER BY created_at DESC
        LIMIT 1
    """, (date,))
    row = cur.fetchone()
    if not row:
        return jsonify(None)

    note_id = row[0]
    cur.execute("SELECT category, score FROM green_note_scores WHERE note_id = %s", (note_id,))
    scores = [{'category': r[0], 'score': r[1]} for r in cur.fetchall()]
    cur.close()
    conn.close()
    return jsonify({
        'date': date,
        'good_1': row[1], 'good_2': row[2], 'good_3': row[3], 'improve': row[4],
        'scores': scores
    })


@app.route('/green_notes/today/<date>', methods=['GET'])
def get_latest_note_for_today(date):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT gn.id, gn.date, gn.good_1, gn.good_2, gn.good_3, gn.improve,
               json_agg(json_build_object('category', gns.category, 'score', gns.score)) as scores
        FROM green_notes gn
        LEFT JOIN green_note_scores gns ON gn.id = gns.note_id
        WHERE gn.date = %s
        GROUP BY gn.id
        ORDER BY gn.created_at DESC
        LIMIT 1
    """, (date,))
    row = cur.fetchone()
    cur.close()
    conn.close()
    if row:
        return jsonify({
            'date': row[1],
            'good_1': row[2],
            'good_2': row[3],
            'good_3': row[4],
            'improve': row[5],
            'scores': row[6]
        })
    return jsonify(None)

@app.route('/green_notes_unsaved/<date>', methods=['GET'])
def get_unsaved_note(date):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT gn.id, gn.date, gn.good_1, gn.good_2, gn.good_3, gn.improve,
               json_agg(json_build_object('category', gns.category, 'score', gns.score)) as scores
        FROM green_notes gn
        LEFT JOIN green_note_scores gns ON gn.id = gns.note_id
        WHERE gn.date = %s
        GROUP BY gn.id, gn.date, gn.good_1, gn.good_2, gn.good_3, gn.improve
        ORDER BY gn.created_at DESC
        LIMIT 1
    """, (date,))
    row = cur.fetchone()
    cur.close()
    conn.close()
    if row:
        return jsonify({
            'key': f"{row[1]} {row[0]}",  # Use date + id as the unique key
            'date': row[1],
            'good_1': row[2],
            'good_2': row[3],
            'good_3': row[4],
            'improve': row[5],
            'scores': row[6]
        })
    return jsonify(None)




if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
