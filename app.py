from flask import Flask, request, jsonify
from flask_cors import CORS
import psycopg2
import os
from flask import jsonify, json
from datetime import datetime, date


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

# ---------- PAGES ----------

current_window_args = {}
should_open_window = False

# Set the window arguments
@app.route('/window_args', methods=['POST'])
def set_window_args():
    global current_window_args
    current_window_args = request.json
    return jsonify({'status': 'ok'})

# Get the window arguments (and clear them after use)
@app.route('/window_args', methods=['GET'])
def get_window_args():
    global current_window_args
    args = current_window_args
    current_window_args = {}  # Clear after fetch
    return jsonify(args)

# Trigger a window open (from child window)
@app.route('/window_request', methods=['POST'])
def trigger_window_open():
    global should_open_window
    should_open_window = True
    return jsonify({'status': 'triggered'})

# Polling route (main window checks this)
@app.route('/window_request', methods=['GET'])
def check_window_request():
    return jsonify({'open': should_open_window})

# Reset the flag after opening
@app.route('/reset_window_request', methods=['POST'])
def reset_window_request():
    global should_open_window
    should_open_window = False
    return jsonify({'status': 'reset'})

# ---------- HOUSES ----------
@app.route('/add_house', methods=['POST'])
def add_house():
    data = request.get_json()
    house_name = data['name']

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("INSERT INTO houses (name) VALUES (%s) ON CONFLICT DO NOTHING", (house_name,))
    conn.commit()
    cur.close()
    conn.close()

    return '', 200

@app.route('/delete_house', methods=['POST'])
def delete_house():
    data = request.get_json()
    house_name = data['name']

    if house_name == 'כללי':
        return jsonify({'error': 'Cannot delete the general house'}), 400

    conn = get_db_connection()
    cur = conn.cursor()

    # 1. Move topics to 'כללי'
    cur.execute(
        "UPDATE topics SET house = %s WHERE house = %s",
        ('כללי', house_name)
    )

    # 2. Delete the house
    cur.execute(
        "DELETE FROM houses WHERE name = %s",
        (house_name,)
    )

    conn.commit()
    cur.close()
    conn.close()

    return '', 200

@app.route('/houses', methods=['GET'])
def get_houses():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT name FROM houses")
    rows = cur.fetchall()
    cur.close()
    conn.close()

    house_list = [row[0] for row in rows]
    return jsonify(house_list)

@app.route('/edit_house', methods=['POST'])
def edit_house():
    data = request.get_json()
    old_name = data['old_name']
    new_name = data['new_name']

    conn = get_db_connection()
    cur = conn.cursor()
    # Update house name in houses table
    cur.execute("UPDATE houses SET name = %s WHERE name = %s", (new_name, old_name))
    # Also update house field in topics
    cur.execute("UPDATE topics SET house = %s WHERE house = %s", (new_name, old_name))
    conn.commit()
    cur.close()
    conn.close()

    return '', 200


# ---------- TOPICS ----------
# GET all topics organized by houses

@app.route('/directories', methods=['GET'])
def get_directories():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, house, name, color, \"order\" FROM topics ORDER BY house, \"order\" ASC")
    rows = cur.fetchall()
    cur.close()
    conn.close()

    houses = {}
    for topic_id, house, name, color, order in rows:
        houses.setdefault(house, []).append({
            'id': topic_id,
            'name': name,
            'color': color,
            'order': order
        })
    return jsonify(houses)


@app.route('/edit_topic', methods=['POST'])
def edit_topic():
    data = request.get_json()
    topic_id = data['id']
    name = data['name']
    color = data['color']

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        UPDATE topics SET name = %s, color = %s WHERE id = %s
    """, (name, color, topic_id))
    conn.commit()
    cur.close()
    conn.close()

    return '', 200


@app.route('/add_topic', methods=['POST'])
def add_topic():
    data = request.get_json()
    name = data['name']
    color = data['color']
    house = data['house']

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO topics (name, color, house, "order")
        VALUES (%s, %s, %s, %s)
    """, (name, color, house, 0))  # default new topic at order=0
    conn.commit()
    cur.close()
    conn.close()

    return '', 200


@app.route('/delete_topic', methods=['POST'])
def delete_topic():
    data = request.get_json()
    topic_id = data['id']

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM topics WHERE id = %s", (topic_id,))
    conn.commit()
    cur.close()
    conn.close()

    return '', 200


@app.route('/move_topic', methods=['POST'])
def move_topic():
    data = request.get_json()
    topic_id = data['topic_id']
    new_house = data['new_house']
    new_order = data['new_order']

    conn = get_db_connection()
    cur = conn.cursor()

    # 1. Update the moved topic to the new house (temporarily give it a special order)
    cur.execute("""
        UPDATE topics SET house = %s, "order" = -1 WHERE id = %s
    """, (new_house, topic_id))
    conn.commit()

    # 2. Fetch all topics in the new house, ordered by "order"
    cur.execute("""
        SELECT id FROM topics WHERE house = %s AND id != %s ORDER BY "order"
    """, (new_house, topic_id))
    other_topics = cur.fetchall()

    # 3. Insert the moved topic at the right place
    all_topics_ordered = []
    inserted = False
    for index, (other_id,) in enumerate(other_topics):
        if index == new_order:
            all_topics_ordered.append(topic_id)  # Insert moved topic here
            inserted = True
        all_topics_ordered.append(other_id)

    if not inserted:
        all_topics_ordered.append(topic_id)  # If new_order > length, add at the end

    # 4. Update the order numbers correctly
    for new_index, tid in enumerate(all_topics_ordered):
        cur.execute("""
            UPDATE topics SET "order" = %s WHERE id = %s
        """, (new_index, tid))

    conn.commit()
    cur.close()
    conn.close()

    return '', 200


@app.route('/toggle_flat', methods=['POST'])
def toggle_flat():
    data = request.get_json()
    topic_id = data['topic_id']
    flat = data['flat']
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("UPDATE topics SET flat = %s WHERE id = %s", (flat, topic_id))
    conn.commit()
    cur.close()
    conn.close()
    return '', 200

@app.route('/topic_details/<int:topic_id>', methods=['GET'])
def topic_details(topic_id):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT name, color, flat FROM topics WHERE id = %s", (topic_id,))
    row = cur.fetchone()
    cur.close()
    conn.close()

    if row:
        return jsonify({'name': row[0], 'color': row[1], 'flat': row[2]})
    else:
        return jsonify({'error': 'Topic not found'}), 404

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
    topic_id = data['topic_id']
    name = data['name']
    section = data['section']

    conn = get_db_connection()
    cur = conn.cursor()

    # Delete from files table
    cur.execute("DELETE FROM files WHERE topic_id = %s AND name = %s", (topic_id, name))

    # Delete from tasks or control table
    if section == 'tasks':
        cur.execute("DELETE FROM tasks WHERE topic_id = %s AND file_name = %s", (topic_id, name))
    elif section in ['plans', 'docs']:
        cur.execute("DELETE FROM control WHERE topic_id = %s AND name_file = %s", (topic_id, name))

    conn.commit()
    cur.close()
    conn.close()
    return '', 200


@app.route('/files/add', methods=['POST'])
def add_file():
    data = request.get_json()
    section = data['section']
    topic_id = data['topic_id']
    name = data['name']

    conn = get_db_connection()
    cur = conn.cursor()

    # Add to files table
    cur.execute("""
        INSERT INTO files (topic_id, section, name, linked, content)
        VALUES (%s, %s, %s, FALSE, '[]')
    """, (topic_id, section, name))

    # If this is a task section, add to tasks table
    if section == 'tasks':
        task_cur = conn.cursor()
        task_cur.execute("SELECT COUNT(*) FROM tasks WHERE section = 'בהמשך'")
        order = task_cur.fetchone()[0]
        task_cur.execute("""
            INSERT INTO tasks (topic_id, file_name, section, "order")
            VALUES (%s, %s, 'בהמשך', %s)
        """, (topic_id, name, order))
        task_cur.close()

    # If plans/docs, add to control table
    elif section in ['plans', 'docs']:
        is_plan = (section == 'plans')
        control_cur = conn.cursor()
        control_cur.execute("SELECT COUNT(*) FROM control WHERE is_plan = %s AND modification_alert = FALSE", (is_plan,))
        order_index = control_cur.fetchone()[0]
        control_cur.execute("""
            INSERT INTO control (name_file, topic_id, is_plan, order_index, modification_alert)
            VALUES (%s, %s, %s, %s, FALSE)
        """, (name, topic_id, is_plan, order_index))
        control_cur.close()

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

@app.route('/linked_files', methods=['GET'])
def get_linked_files():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT f.topic_id, f.name, f.section
        FROM files f
        JOIN topics t ON f.topic_id = t.id
        WHERE f.linked = TRUE
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()

    result = [
        {
            'topic_id': row[0],
            'file_name': row[1],
            'section': row[2]
        }
        for row in rows
    ]
    return jsonify(result)

# ---------- TASKS ----------

@app.route('/unclassified_tasks')
def get_unclassified():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT \"order\", content FROM unclassified_tasks ORDER BY \"order\"")
    rows = cur.fetchall()
    return jsonify([{'order': r[0], 'content': r[1], 'topic_id': 1} for r in rows])  # Use dummy topic_id=1 for coloring

@app.route('/tasks')
def get_tasks():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT topic_id, file_name, section, \"order\" FROM tasks")
    rows = cur.fetchall()
    return jsonify([{'topic_id': r[0], 'file_name': r[1], 'section': r[2], 'order': r[3]} for r in rows])

@app.route('/reorder_task', methods=['POST'])
def reorder_task():
    conn = get_db_connection()
    cur = conn.cursor()
    data = request.json
    tasks = data['tasks']  # list of {topic_id, file_name, order, section}

    for task in tasks:
        cur.execute("""
            UPDATE tasks
            SET section = %s, \"order\" = %s
            WHERE topic_id = %s AND file_name = %s
        """, (task['section'], task['order'], task['topic_id'], task['file_name']))

    conn.commit()
    return jsonify({'status': 'success'})

@app.route('/reorder_unclassified', methods=['POST'])
def reorder_unclassified():
    conn = get_db_connection()
    cur = conn.cursor()
    data = request.json
    tasks = data['tasks']

    for task in tasks:
        cur.execute("""
            UPDATE unclassified_tasks
            SET \"order\" = %s
            WHERE content = %s
        """, (task['order'], task['content']))

    conn.commit()
    return jsonify({'status': 'success'})

@app.route('/add_task', methods=['POST'])
def add_task():
    conn = get_db_connection()
    cur = conn.cursor()
    data = request.json
    topic_id = data['topic_id']
    file_name = data['file_name']

    cur.execute("SELECT COUNT(*) FROM tasks WHERE section = 'בהמשך'")
    order = cur.fetchone()[0]
    cur.execute("INSERT INTO tasks (topic_id, file_name, section, \"order\") VALUES (%s, %s, %s, %s)",
                   (topic_id, file_name, 'בהמשך', order))
    conn.commit()
    return jsonify({'status': 'task added'})

@app.route('/add_unclassified', methods=['POST'])
def add_unclassified():
    conn = get_db_connection()
    cur = conn.cursor()
    data = request.json
    content = data['content']

    cur.execute("SELECT COUNT(*) FROM unclassified_tasks")
    order = cur.fetchone()[0]
    cur.execute("INSERT INTO unclassified_tasks (\"order\", content) VALUES (%s, %s)", (order, content))
    conn.commit()
    return jsonify({'status': 'unclassified task added'})

@app.route('/delete_unclassified', methods=['POST'])
def delete_unclassified():
    data = request.json
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        DELETE FROM unclassified_tasks
        WHERE content = %s AND "order" = %s
    """, (data['content'], data['order']))

    if cur.rowcount == 0:
        return jsonify({'error': 'Task not found'}), 404

    conn.commit()
    return jsonify({'status': 'deleted'})


@app.route('/delete_task_and_file', methods=['POST'])
def delete_task_and_file():
    data = request.json
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM tasks WHERE topic_id = %s AND file_name = %s",
                (data['topic_id'], data['file_name']))
    cur.execute("DELETE FROM files WHERE topic_id = %s AND name = %s",
                (data['topic_id'], data['file_name']))
    conn.commit()
    return jsonify({'status': 'deleted'})

# ---------------- TRACKING ----------------
@app.route('/get_food')
def get_food():
    date = request.args.get('date')
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT name, calories, protein FROM food WHERE date = %s", (date,))
    rows = cur.fetchall()
    result = [{'name': r[0], 'calories': r[1], 'protein': r[2]} for r in rows]
    return jsonify(result)

@app.route('/add_food', methods=['POST'])
def add_food():
    data = request.json
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO food (date, name, calories, protein) VALUES (%s, %s, %s, %s)",
        (data['date'], data['name'], data['calories'], data['protein'])
    )
    conn.commit()
    return jsonify({'status': 'success'})

@app.route('/get_tracking')
def get_tracking():
    reset_tracking_daily()  # call it here automatically
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT name, time, amount, done, content FROM tracking")
    rows = cur.fetchall()
    result = []
    for r in rows:
        result.append({
            'name': r[0],
            'time': r[1],
            'amount': r[2],
            'done': r[3],
            'content': r[4]
        })
    return jsonify(result)

@app.route('/reset_tracking_daily')
def reset_tracking_daily():
    today_str = date.today().strftime('%Y-%m-%d')
    conn = get_db_connection()
    cur = conn.cursor()

    # Get all items where time < today
    cur.execute("SELECT name, time FROM tracking")
    rows = cur.fetchall()

    for name, t in rows:
        if t != today_str:
            cur.execute("UPDATE tracking SET done = 0, time = %s WHERE name = %s", (today_str, name))

    conn.commit()
    return jsonify({'status': 'reset done where needed'})


@app.route('/update_tracking_done', methods=['POST'])
def update_tracking_done():
    data = request.json
    name = data['name']
    index = data['index']
    checked = data['checked']

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT done FROM tracking WHERE name = %s", (name,))
    current_done = cur.fetchone()[0] or 0

    new_done = current_done + 1 if checked else current_done - 1
    new_done = max(0, new_done)  # prevent negative

    cur.execute("UPDATE tracking SET done = %s WHERE name = %s", (new_done, name))
    conn.commit()
    return jsonify({'status': 'updated'})


@app.route('/add_tracking_item', methods=['POST'])
def add_tracking_item():
    data = request.json
    name = data['name']
    amount = data['amount']
    content = data['content']
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO tracking (name, time, amount, done, content) VALUES (%s, %s, %s, %s, %s)",
        (name, datetime.now().strftime('%Y-%m-%d'), amount, 0, content)
    )
    conn.commit()
    return jsonify({'status': 'added'})


@app.route('/delete_food', methods=['POST'])
def delete_food():
    data = request.json
    name = data['name']
    date_ = data['date']
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM food WHERE name = %s AND date = %s", (name, date_))
    conn.commit()
    return jsonify({'status': 'deleted'})


@app.route('/delete_tracking_item', methods=['POST'])
def delete_tracking_item():
    data = request.json
    name = data['name']
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM tracking WHERE name = %s", (name,))
    conn.commit()
    return jsonify({'status': 'deleted'})


# ---------- CONTROL ----------

@app.route('/get_control_files')
def get_control_files():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT name_file, topic_id, is_plan, order_index, modification_alert FROM control")
    rows = cur.fetchall()
    result = [
        {
            'name_file': r[0],
            'topic_id': r[1],
            'is_plan': r[2],
            'order_index': r[3],
            'modification_alert': r[4]
        }
        for r in rows
    ]
    return jsonify(result)


@app.route('/update_control_file', methods=['POST'])
def update_control_file():
    data = request.json
    name_file = data['name_file']
    topic_id = data['topic_id']
    is_plan = data['is_plan']
    modification_alert = data['modification_alert']
    order_index = data['order_index']

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """UPDATE control
           SET is_plan = %s, modification_alert = %s, order_index = %s
           WHERE name_file = %s AND topic_id = %s""",
        (is_plan, modification_alert, order_index, name_file, topic_id)
    )
    conn.commit()
    return jsonify({'status': 'updated'})


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
