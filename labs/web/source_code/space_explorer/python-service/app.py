from flask import Flask, request, jsonify
import random
import os

app = Flask(__name__)

COSMIC_ANOMALIES = [
    {
        "name": "Quantum Singularity",
        "src": "https://images.unsplash.com/photo-1462331940025-496dfbfc7564?w=600"
    },
    {
        "name": "Nebula Cluster",
        "src": "https://images.unsplash.com/photo-1506318137071-a8e063b4bec0?w=600"
    },
    {
        "name": "Pulsar Emission",
        "src": "https://images.unsplash.com/photo-1465101162946-4377e57745c3?w=600"
    },
    {
        "name": "Dark Matter Veil",
        "src": "https://images.unsplash.com/photo-1534796636912-3b95b3ab5986?w=600"
    },
    {
        "name": "Supernova Remnant",
        "src": "https://images.unsplash.com/photo-1454789548928-9efd52dc4031?w=600"
    }
]

@app.route('/execute', methods=['POST'])
def execute():
    if not request.is_json:
        return jsonify({"error": "Invalid transmission format"}), 400

    data = request.get_json()
    
    if 'action' not in data:
        return jsonify({"error": "No command received"}), 400

    if data['action'] == "getcosmic":
        anomaly = random.choice(COSMIC_ANOMALIES)
        return jsonify(anomaly)
    elif data['action'] == "getSecureCode":
        return jsonify({
            "flag": os.getenv("FLAG", "HTB{flag_not_set}"),
            "name": "Captain's Log",
            "src": "https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600"
        })
    else:
        return jsonify({"error": "Unknown command"}), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8081, debug=True)
