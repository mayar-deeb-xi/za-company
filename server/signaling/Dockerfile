FROM python:3.13-slim

ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY turn.py rooms.py main.py ./

RUN useradd --system --no-create-home signaling
USER signaling

EXPOSE 8765
HEALTHCHECK --interval=30s --timeout=3s \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8765/healthz')"
CMD ["python", "main.py"]
