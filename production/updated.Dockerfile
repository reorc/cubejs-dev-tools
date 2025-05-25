FROM node:20.17.0-bookworm-slim AS builder

WORKDIR /cube
COPY . .

RUN yarn policies set-version v1.22.22
# Yarn v1 uses aggressive timeouts with summing time spending on fs, https://github.com/yarnpkg/yarn/issues/4890
RUN yarn config set network-timeout 120000 -g

# Required for node-oracledb to buld on ARM64
RUN apt-get update \
    # python3 package is necessary to install `python3` executable for node-gyp
    # libpython3-dev is needed to trigger post-installer to download native with python
    && apt-get install -y python3 python3.11 libpython3.11-dev gcc g++ make cmake ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Register the local schema-compiler package
WORKDIR /cube/packages/cubejs-schema-compiler
RUN yarn link
WORKDIR /cube/packages/cubejs-clickhouse-driver
RUN yarn link
WORKDIR /cube/packages/cubejs-backend-shared
RUN yarn link


WORKDIR /cube
# We are copying root yarn.lock file to the context folder during the Publish GH
# action. So, a process will use the root lock file here.
RUN yarn install --prod \
    # Link to use local schema-compiler
    && yarn link @cubejs-backend/schema-compiler \
    && yarn link @cubejs-backend/clickhouse-driver \
    && yarn link @cubejs-backend/shared \
    # Manually install cross-fetch for clickhouse-driver
    && yarn add cross-fetch --ignore-optional \
    # Remove DuckDB sources to reduce image size
    && rm -rf /cube/node_modules/duckdb/src \
    && yarn cache clean

FROM node:20.17.0-bookworm-slim

ARG IMAGE_VERSION=unknown

ENV CUBEJS_DOCKER_IMAGE_VERSION=$IMAGE_VERSION
ENV CUBEJS_DOCKER_IMAGE_TAG=latest

RUN DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends libssl3 python3.11 libpython3.11-dev \
    && rm -rf /var/lib/apt/lists/*

RUN yarn policies set-version v1.22.22

ENV NODE_ENV=production

WORKDIR /cube

COPY --from=builder /cube .

# Register and link the schema-compiler package in the final stage
WORKDIR /cube/packages/cubejs-schema-compiler
RUN yarn link
WORKDIR /cube/conf
RUN yarn link @cubejs-backend/schema-compiler

WORKDIR /cube/packages/cubejs-clickhouse-driver
RUN yarn link
WORKDIR /cube/conf
RUN yarn link @cubejs-backend/clickhouse-driver

WORKDIR /cube/packages/cubejs-backend-shared
RUN yarn link
WORKDIR /cube/conf
RUN yarn link @cubejs-backend/shared

WORKDIR /cube

# By default Node dont search in parent directory from /cube/conf, @todo Reaserch a little bit more
ENV NODE_PATH=/cube/conf/node_modules:/cube/node_modules
ENV PYTHONUNBUFFERED=1
RUN ln -s /cube/node_modules/.bin/cubejs /usr/local/bin/cubejs
RUN ln -s /cube/node_modules/.bin/cubestore-dev /usr/local/bin/cubestore-dev

WORKDIR /cube/conf

EXPOSE 4000

CMD ["cubejs", "server"]
