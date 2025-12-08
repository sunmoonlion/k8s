#! /usr/bin/env bash

# Let the DB start
python /app/app/backend_pre_start.py

# Run migrations (if alembic is configured)
# alembic upgrade head

# Create initial data in DB
python /app/app/initial_data.py

