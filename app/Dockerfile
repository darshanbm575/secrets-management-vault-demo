FROM python:3.12.4-slim

RUN groupadd --system app && useradd --system --gid app app

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

USER app
CMD ["python", "main.py"]
