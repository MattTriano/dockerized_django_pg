
## Initial setup
You'll need to have a development environment with django to develop your site. I am most familiar with conda, but it would probably be wiser to use venv if as I plan on dockerizing applications. 

```bash
(base) matt@matt:~/...$ conda activate some_env_w_the_version_of_python_I_want
(some_env_w_the_version_of_python_I_want) matt@matt:~/...$ python -m venv .venv
(some_env_w_the_version_of_python_I_want) matt@matt:~/...$ conda deactivate
(base) matt@matt:~/...$ conda deactivate
matt@matt:~/...$ source .venv/bin/activate
(.venv) matt@matt:~/...$ python -m pip install django
(.venv) matt@matt:~/...$ python -m pip install psycopg2-binary
(.venv) matt@matt:~/...$ python -m pip install django-debug-toolbar
```
**Note: from here on, assume the `.venv` env is activated unless otherwise indicated.**

## Create a project

```bash
~/...$ django-admin startproject mysite
```

### Start serving the site locally

```bash
~/...$ python mysite/manage.py runserver
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
COPY /mysite .
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
      - ./mysite:/code
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

### Add a postgres database to the application

There isn't too much I want to change from the base image, but I'll still indicate the image in a separate Dockerfile, `postgres.Dockerfile` 

```text
FROM postgres:14.5
```

and I'll update the `docker-compose.yml` file with a definition for this service,

```yml
services:
  py:
    ...
  database:
    build:
      context: ./
      dockerfile: Dockerfiles/postgres.Dockerfile
    environment:
      POSTGRES_USER: "${DB_USER}"
      POSTGRES_PASSWORD: "${DB_PASSWORD}"
    ports:
      - "5789:5432"
    volumes:
      - django_pg_data:/var/lib/postgresql/data/

volumes:
  django_pg_data:
```

In the `docker-compose.yml`, we told docker to set environment variables `POSTGRES_USER` to the value of variable `DB_USER` and `POSTGRES_PASSWORD` to the value of variable `DB_PASSWORD`. To resolve these values, docker will look for a file named `.env`. If it doesn't find that file, it will just use blank strings for those variables (even if you define an `env_file` with a name other than just `.env`) So let's create that file and define variables `DB_USER` and `DB_PASSWORD`.

```bash
~/...$ touch .env
```

Open up that `.env` file and define your credentials for accessing the database

```text
DB_USER=matt
DB_PASSWORD=matts_db_password
```

Note: if you want to keep your credentials from `.env` files private, you should add `*.env` to your `.gitignore` file.

and for the container serving django to connect to the database, you'll also have to add those environment variables to the `py` service specification.
```yaml
  py:
    ...
    environment:
      POSTGRES_USER: "${DB_USER}"
      POSTGRES_PASSWORD: "${DB_PASSWORD}"
    ...
```

#### Making a persistant postgres volume

The `database` service from the `docker-compose.yml` file also includes a volume definition connecting `django_pg_data` on the host machine to the path `/var/lib/postgresql/data/` (postgres's default location for storing database data). There's also a `volumes` definition at the bottom of the file listing the name `django_pg_data`, which tells docker to create a volume named `django_pg_data` somewhere on the host system. 

#### Modify the django app to connect to the postgres database

Open up the `mysite/mysite/settings.py` file, add in a line to `import os`, and change the `DATABASES["default"]` value from the `sqlite3` name and engine to 

```python
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": "postgres",
        "USER": os.environ["POSTGRES_USER"],
        "PASSWORD": os.environ["POSTGRES_PASSWORD"],
        "HOST": "database",  # set in docker-compose.yml
        "PORT": 5432,  # default postgres port
    }
}
```

Now your system should be ready to start up.

```bash
$ docker-compose build
$ docker-compose up
```

If everything builds alright, get an interactive terminal to the container serving your django site (check `docker ps` for that container's name; it will probably be something like `django_postgres_docker_py_1`)

```bash
~/...$ docker exec -ti django_postgres_docker_py_1 /bin/bash
```

which will give you a bash terminal, from which you can migrate your initial database model and create a superuser

```bash
root@bc2fa6d66a31:/code# python manage.py migrate
root@bc2fa6d66a31:/code# python manage.py createsuperuser
```






## Extras

### Get an interactive terminal within your container
To get an interactive terminal within your container, first determine the name of your `database` container via 

```bash
$ docker ps
```

then plug that container name into the command below

```bash
docker exec -ti <your_database_container> /bin/bash
```

#### Connect to your database via psql (from an interactive terminal)

```bash
root@<container_id_numbers>: /# psql -U <your DB_USER name>
```