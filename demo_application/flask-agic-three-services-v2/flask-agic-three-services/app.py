import os
from flask import Flask, jsonify, render_template

app = Flask(__name__)

SERVICE_NAME = os.getenv("SERVICE_NAME", "user").lower()
ROUTE_PATH = os.getenv("ROUTE_PATH", "/user")

# Each independently built image selects its own HTML page.
PAGE_BY_SERVICE = {
    "user": "user.html",
    "order": "order.html",
    "payment": "payment.html",
}

@app.get(ROUTE_PATH)
def home():
    page = PAGE_BY_SERVICE.get(SERVICE_NAME)
    if page is None:
        return jsonify(error="Unknown service", service=SERVICE_NAME), 500
    return render_template(page)

@app.get("/health")
def health():
    return jsonify(status="healthy", service=SERVICE_NAME), 200

if __name__ == "__main__":
    # Development only. Docker runs this app with Gunicorn.
    app.run(host="0.0.0.0", port=5000)
