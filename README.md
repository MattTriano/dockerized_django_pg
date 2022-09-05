
## Initial setup
You'll need to have a development environment with django to develop your site. I am most familiar with conda, but it would probably be wiser to use venv if as I plan on dockerizing applications. 

```bash
(base) matt@matt:~/...$ conda activate some_env_w_the_version_of_python_I_want
(some_env_w_the_version_of_python_I_want) matt@matt:~/...$ python -m venv .venv
(some_env_w_the_version_of_python_I_want) matt@matt:~/...$ conda deactivate
(base) matt@matt:~/...$ conda deactivate
matt@matt:~/...$ source .venv/bin/activate
(.venv) matt@matt:~/...$ python -m pip install django
(.venv) matt@matt:~/...$ python -m django --version
4.1.1
```
**Note: from here on, assume the `.venv` env is activated unless otherwise indicated.**

## Create a project

```bash
~/...$ django-admin startproject mysite .
```

### Start serving the site locally

```bash
~/...$ python manage.py runserver
```

This will start up server serving your site locally to (default) port 8000, and you can access that site at http://127.0.0.1:8000/.

### Setting up a Dockerfile for your python version

First, create a Dockerfiles directory (`Dockerfiles/`) and an empty file (`python.Dockerfile`)

```bash
~/...$ mkdir Dockerfiles && touch Dockerfiles/python.Dockerfile
```

create an empty `.dockerignore` file,

```bash
~/...$ touch .dockerignore
```

and freeze your current dependencies

```bash
~/...$ python -m pip freeze > requirements.txt
```

#### Writing your `.dockerignore` file

We don't want to build everything into our container, so we'll tell docker to ignore some things. In the `.dockerignore` file, add lines

```txt
.venv
.git
.gitignore
```

#### Writing python.Dockerfile

In the empty `python.Dockerfile` file, first indicate an image to build on (replacing the version number with the update-to-date number [on docker hub](https://hub.docker.com/_/python/tags))

```bash
FROM python:3.10.6-slim-bullseye
```

Then set these environment variables

```bash
# Set env vars to prevent automatic pip update checks, .pyc files, or console output buffering
ENV PIP_DISABLE_PIP_VERSION_CHECK 1
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
```

specify the workdir in your container, copy in your `requirements.txt` file, and copy in project code

```bash
WORKDIR /code

COPY ./requirements.txt .
RUN pip install -r requirements.txt

# Copy project
COPY . .
```

### Setting up a `docker-compose.yml` file to orchestrate services

Indicate the docker-compose version to use and then start defining services.

The `py` service will correspond to `python.Dockerfile` and we have to connect things on the host machine to inside the resulting containter. To build the container correctly, we'll have to indicate the context on the host machine that matches things indicated in the Dockerfile (which essentially means our context has to contain the `requirements.txt` file that is copied into the container's workdir, `/code`). Then we'll connect ports, provide a command to start the server, and hook up a volume so we can persist data from the container.

```yml
version: "3.9"

services:
  py:
    build:
      context: ./
      dockerfile: Dockerfiles/python.Dockerfile
    ports:
      - "8000:8000"
    command: python manage.py runserver 0.0.0.0:8000
    volumes:
      - .:/code
```

### Building and running the `docker-compose` application

After that's written, build the application via

```bash
~/...$ docker-compose build
```

and start it up via 

```bash
~/...$ docker-compose up
```

