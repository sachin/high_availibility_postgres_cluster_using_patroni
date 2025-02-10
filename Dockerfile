FROM postgres:17.2-alpine

RUN apk add --no-cache python3 py3-pip py3-psycopg2 gcc python3-dev musl-dev linux-headers curl gettext && \
    python3 -m venv /venv && \
    . /venv/bin/activate && \
    pip install --upgrade pip && \
    pip install patroni[etcd] psycopg2-binary && \
    chown -R postgres:postgres /venv

RUN mkdir -p /etc/patroni && \
    chown -R postgres:postgres /etc/patroni && \
    chmod 700 /etc/patroni && \
    mkdir -p /var/run/postgresql && \
    chown -R postgres:postgres /var/run/postgresql && \
    chmod 700 /var/run/postgresql && \
    mkdir -p /var/lib/postgresql/data && \
    mkdir -p /var/lib/postgresql/data/pg_hba.conf.d && \
    echo "host replication replicator all md5" >> /var/lib/postgresql/data/pg_hba.conf.d/replication.conf && \
    echo "host all all all md5" >> /var/lib/postgresql/data/pg_hba.conf.d/local.conf

COPY config.yml /etc/patroni/config.template.yml
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh && \
    chown postgres:postgres /etc/patroni/config.template.yml && \
    chmod 640 /etc/patroni/config.template.yml

USER postgres
ENV PATH="/venv/bin:$PATH"

ENTRYPOINT ["/entrypoint.sh"]