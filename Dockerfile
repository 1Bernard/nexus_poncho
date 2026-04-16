# =============================================================================
# Stage 1: Build
# Compiles the application and produces a release artifact.
# =============================================================================
FROM elixir:1.19-alpine AS builder

RUN apk add --no-cache build-base git npm

RUN mix local.hex --force && mix local.rebar --force

WORKDIR /app

ENV MIX_ENV=prod

# Copy shared library first (dependency of both nexus and nexus_web)
COPY nexus_shared/mix.exs nexus_shared/mix.lock ./nexus_shared/
RUN cd nexus_shared && mix deps.get --only prod

# Fetch deps for the domain core
COPY nexus/mix.exs nexus/mix.lock ./nexus/
RUN cd nexus && mix deps.get --only prod

# Fetch deps for the web gateway
COPY nexus_web/mix.exs nexus_web/mix.lock ./nexus_web/
RUN cd nexus_web && mix deps.get --only prod

# Copy source
COPY nexus_shared/ ./nexus_shared/
COPY nexus/ ./nexus/
COPY nexus_web/ ./nexus_web/

# Compile and build assets
RUN cd nexus_web && \
    mix assets.deploy && \
    mix release

# =============================================================================
# Stage 2: Runtime
# Minimal image containing only the compiled release — no build tools.
# =============================================================================
FROM alpine:3.20 AS runtime

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

# Copy only the release artifact from the builder stage
COPY --from=builder /app/nexus_web/_build/prod/rel/nexus_web ./

ENV HOME=/app
ENV PHX_SERVER=true

EXPOSE 4000

CMD ["bin/nexus_web", "start"]
