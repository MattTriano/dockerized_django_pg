FROM python:3.10.6-slim-bullseye

# Set env vars to prevent automatic pip update checks, .pyc files, or console output buffering
ENV PIP_DISABLE_PIP_VERSION_CHECK 1
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

WORKDIR /code

COPY ./requirements.txt .
RUN pip install -r requirements.txt

# Copy project
COPY /mysite .