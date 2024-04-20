FROM python:slim

# Install Poetry
RUN pip install six
RUN pip install poetry

WORKDIR /opt/server

# Install dependencies:
COPY pyproject.toml poetry.lock ./
RUN poetry install

COPY server/ ./

ENV FLAGS_DATABASE=/var/destructivefarm/flags.sqlite 
ENV FLASK_APP=/opt/server/standalone.py

VOLUME [ "/var/destructivefarm" ]
EXPOSE 5000

# Run the application:
ENTRYPOINT "./start_server.sh"
