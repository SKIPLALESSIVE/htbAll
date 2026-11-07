import hashlib
import os
import sqlite3
import subprocess
from functools import wraps
from pathlib import Path

from flask import Flask, abort, jsonify, redirect, render_template, request, send_from_directory, session, url_for

app = Flask(__name__)
app.config.from_mapping(
    DATABASE=os.environ.get("LEDGER_DATABASE", "/opt/ledger/data/ledger.db"),
    REPORT_DIR=os.environ.get("LEDGER_REPORT_DIR", "/opt/ledger/reports"),
    SECRET_KEY=os.environ.get("FLASK_SECRET_KEY", "development-only-key"),
)


def query_one(sql: str, parameters=()):
    with sqlite3.connect(app.config["DATABASE"]) as database:
        database.row_factory = sqlite3.Row
        return database.execute(sql, parameters).fetchone()


def admin_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        if session.get("role") != "admin":
            return redirect(url_for("login"))
        return view(*args, **kwargs)

    return wrapped


@app.get("/")
def index():
    return render_template("index.html")


@app.get("/company")
def company():
    return render_template("company.html")


@app.get("/handbook")
def handbook():
    return render_template("handbook.html")


@app.get("/service-notices")
def service_notices():
    return render_template("service-notices.html")


@app.get("/careers")
def careers():
    # World-building page. It explicitly states that the partner portal is not
    # hosted here so it cannot become a misleading enumeration branch.
    return render_template("careers.html")


@app.get("/api/v1/legacy/status")
def legacy_status():
    # Legacy health endpoint that guides an Easy player back to the directory
    # API used by the login page instead of creating a dead-end rabbit hole.
    return jsonify(
        {
            "service": "northbridge-ledger-legacy",
            "state": "degraded",
            "component": "archive-tape-daemon",
            "detail": "Reconcile queue drained; connector is pending cutover.",
            "operator_contact": "night-ops (internal directory only)",
            "directory_api": "/api/v1/directory/search",
        }
    )


@app.route("/login", methods=["GET", "POST"])
def login():
    error = None
    if request.method == "POST":
        username = request.form.get("username", "")
        supplied_hash = hashlib.sha256(request.form.get("password", "").encode()).hexdigest()
        user = query_one(
            "SELECT username, password_hash, role FROM users WHERE username = ?",
            (username,),
        )
        if user and supplied_hash == user["password_hash"]:
            session.clear()
            session["username"] = user["username"]
            session["role"] = user["role"]
            return redirect(url_for("reports"))
        error = "Invalid credentials"
    return render_template("login.html", error=error)


@app.get("/api/v1/directory/search")
def directory_search():
    term = request.args.get("name", "")
    if len(term) < 2:
        return jsonify([])
    # Intentional challenge vulnerability: SQL injection in a legacy autocomplete API.
    sql = f"SELECT username, role FROM users WHERE username LIKE '%{term}%' LIMIT 5"
    try:
        with sqlite3.connect(app.config["DATABASE"]) as database:
            database.row_factory = sqlite3.Row
            results = [dict(row) for row in database.execute(sql).fetchall()]
    except sqlite3.Error:
        results = []
    return jsonify(results)


@app.get("/logout")
def logout():
    session.clear()
    return redirect(url_for("index"))


@app.get("/reports")
@admin_required
def reports():
    report_dir = Path(app.config["REPORT_DIR"])
    names = sorted(path.name for path in report_dir.glob("*.txt"))
    return render_template("reports.html", reports=names)


@app.get("/admin/imports")
@admin_required
def imports():
    return render_template("imports.html")


@app.get("/admin/audit")
@admin_required
def audit():
    return render_template("audit.html")


@app.get("/admin/settings")
@admin_required
def settings():
    return render_template("settings.html")


@app.get("/export/<path:name>")
@admin_required
def export(name):
    if not name.endswith(".txt") or Path(name).name != name:
        abort(404)
    return send_from_directory(app.config["REPORT_DIR"], name, as_attachment=True)


@app.route("/admin/diagnostics", methods=["GET", "POST"])
@admin_required
def diagnostics():
    output = None
    host = "127.0.0.1"
    if request.method == "POST":
        host = request.form.get("host", "")
        # Intentional challenge vulnerability: shell injection in a legacy diagnostic.
        command = f"ping -c 1 -W 1 {host}"
        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=4,
            )
            output = (result.stdout + result.stderr)[:8000]
        except subprocess.TimeoutExpired:
            output = "Diagnostic timed out"
    return render_template("diagnostics.html", host=host, output=output)

