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
    freetds-dev

WORKDIR /app

COPY Gemfile* ./

RUN gem update bundler && \
    bundle config set force_ruby_platform true && \
    bundle install --jobs $(nproc) --retry 3

COPY . .

ENV RAILS_ENV=development

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]