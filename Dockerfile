FROM python:3.8-slim AS base

# Setup env
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8


FROM base AS python-deps

# Install pipenv and compilation dependencies
RUN pip install pipenv

# Install python dependencies in /.venv
COPY Pipfile .
COPY Pipfile.lock .
RUN PIPENV_VENV_IN_PROJECT=1 pipenv install --deploy
RUN /.venv/bin/python -m pip install --upgrade pip


FROM base AS runtime

# Create and switch to a new user
RUN apt-get update && apt-get install -y make curl

RUN useradd --create-home appuser
WORKDIR /home/appuser
USER appuser

# Copy virtual env from python-deps stage
COPY --chown=appuser:appuser --from=python-deps /.venv /.venv
ENV PATH="/.venv/bin:$PATH"

# Install application into container
COPY --chown=appuser:appuser entrypoint.sh /home/appuser
COPY --chown=appuser:appuser core /home/appuser

EXPOSE 8000

ENTRYPOINT ["sh", "entrypoint.sh"]
CMD ["gunicorn", "core.wsgi:application", "--bind", "0.0.0.0:8000", "--timeout", "300", "--worker-tmp-dir", "/dev/shm", "--workers=2", "--threads=4", "--worker-class=gthread"]