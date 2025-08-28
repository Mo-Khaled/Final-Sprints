from flask import Flask, render_template, request, redirect, url_for, Response
from pymongo import MongoClient
import os
import time

app = Flask(__name__)

# --- MongoDB Connection ---
mongo_uri = os.getenv("MONGO_URI", "mongodb://localhost:27017/")
client = MongoClient(mongo_uri)
db = client["todo_db"]
tasks_collection = db["tasks"]

# Simple metrics storage
app_start_time = time.time()

# --- Routes ---
@app.route("/live")
def live():
    return "live"

@app.route("/health")
def health():
    """Health check endpoint"""
    try:
        db.command('ping')
        return "healthy"
    except Exception as e:
        return f"unhealthy: {str(e)}", 500

@app.route("/metrics")
def metrics():
    """Basic Prometheus metrics endpoint"""
    try:
        task_count = tasks_collection.count_documents({})
        uptime = time.time() - app_start_time
        
        # Check DB connection
        db.command('ping')
        db_connected = 1
    except Exception:
        task_count = 0
        uptime = time.time() - app_start_time
        db_connected = 0
    
    metrics_text = f"""# HELP flask_app_tasks_total Total number of tasks
# TYPE flask_app_tasks_total gauge
flask_app_tasks_total {task_count}

# HELP flask_app_uptime_seconds Application uptime in seconds
# TYPE flask_app_uptime_seconds counter
flask_app_uptime_seconds {uptime:.2f}

# HELP flask_app_database_connected Database connection status
# TYPE flask_app_database_connected gauge
flask_app_database_connected {db_connected}
"""
    
    return Response(metrics_text, mimetype='text/plain')

@app.route("/")
def index():
    tasks = list(tasks_collection.find())
    return render_template("index.html", tasks=tasks)

@app.route("/add", methods=["POST"])
def add_task():
    task = request.form.get("task")
    if task:
        tasks_collection.insert_one({"task": task})
    return redirect(url_for("index"))

@app.route("/delete/<task_id>")
def delete_task(task_id):
    from bson.objectid import ObjectId
    tasks_collection.delete_one({"_id": ObjectId(task_id)})
    return redirect(url_for("index"))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)