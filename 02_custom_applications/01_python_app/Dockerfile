FROM alpine

RUN apk update && apk add --no-cache python3 py3-flask
COPY app.py /app/app.py

CMD ["python3", "/app/app.py"]