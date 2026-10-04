# Pinned upstream; no package installation or upgrades.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
USER 0:0
# Fail closed if upstream changes. Bulk writes must not issue runtime DDL.
RUN /ragflow/.venv/bin/python3 <<'PYCODE'
from hashlib import sha256
from pathlib import Path
path = Path('/ragflow/api/db/db_utils.py')
source = path.read_bytes()
assert sha256(source).hexdigest() == '4db6691cd806ca04ef48f6cd034a55d90704ede815c807f57f8b1b0d38c30779'
before = b'    DB.create_tables([model])\n'
after = (b'    if not model.table_exists():\n'
         b'        raise RuntimeError("Schema is not initialized; run the dedicated initialization Job")\n')
assert source.count(before) == 1
path.write_bytes(source.replace(before, after))
PYCODE
RUN chmod 0755 /root && chmod -R a+rX /root/nltk_data
ENV NLTK_DATA=/root/nltk_data
USER 1000:1000
RUN /ragflow/.venv/bin/python3 -c "import sys,ruamel.yaml; assert sys.version_info[:2] == (3,13)"
