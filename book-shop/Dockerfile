FROM python:3.11-slim

WORKDIR /app

RUN pip install --upgrade pip && pip install poetry

COPY pyproject.toml poetry.lock* /app/
RUN poetry install --no-root --only main

COPY . /app/

EXPOSE 80

CMD ["poetry", "run", "gunicorn", "--bind", "0.0.0.0:80", "book_shop.wsgi:application"]


