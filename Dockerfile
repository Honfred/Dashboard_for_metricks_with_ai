ARG RUBY_VERSION=3.1.4-alpine3.18
FROM ruby:$RUBY_VERSION

RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    tzdata \
    libxml2-dev \
    libxslt-dev \
    libffi-dev \
    openssl-dev \
    gmp-dev \
    icu-dev \
    zlib-dev \
    nodejs \
    yarn \
    shared-mime-info \
    linux-headers \
    libcurl \
    uchardet \
    libarchive \
    freetds-dev \
    yaml-dev \
    libc6-compat \
    gcompat

WORKDIR /app

COPY Gemfile* ./

# Используем системные библиотеки для nokogiri
RUN bundle config build.nokogiri --use-system-libraries && \
    bundle install --jobs $(nproc) --retry 3

# Копируем код приложения: образ из ghcr.io самодостаточен.
# В docker-compose код по-прежнему монтируется томом поверх копии.
COPY . .

ENV RAILS_ENV=development

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]