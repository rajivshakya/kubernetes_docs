FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY templates/ ./templates/

ARG SERVICE_NAME=user
ARG ROUTE_PATH=/user
ENV SERVICE_NAME=${SERVICE_NAME}
ENV ROUTE_PATH=${ROUTE_PATH}

EXPOSE 5000

CMD ["sh", "-c", "gunicorn --bind 0.0.0.0:5000 --workers 2 app:app"]
