# Multi-stage build, see https://docs.docker.com/develop/develop-images/multistage-build/
FROM alpine AS builder

ENV VERSION 0.12.1

ADD https://github.com/sabre-io/Baikal/releases/download/$VERSION/baikal-$VERSION.zip .
RUN apk add unzip && unzip -q baikal-$VERSION.zip

# Final Docker image
FROM nginx:1.31.3

# Install dependencies: PHP (with libffi dependency) & SQLite3
RUN curl -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg &&\
  apt update                  &&\
  apt install -y lsb-release  &&\
  echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list &&\
  apt remove -y lsb-release   &&\
  apt update                  &&\
    apt install -y            \
    php8.5-curl               \
    php8.5-fpm                \
    php8.5-mbstring           \
    php8.5-mysql              \
    php8.5-pgsql              \
    php8.5-sqlite3            \
    php8.5-xml                \
    sqlite3                   \
    msmtp msmtp-mta           &&\
  rm -rf /var/lib/apt/lists/* &&\
  sed -i 's/www-data/nginx/' /etc/php/8.5/fpm/pool.d/www.conf &&\
  sed -i 's/^listen = .*/listen = \/var\/run\/php-fpm.sock/' /etc/php/8.5/fpm/pool.d/www.conf &&\
  { \
    echo 'pm = dynamic'; \
    echo 'pm.max_children = 20'; \
    echo 'pm.start_servers = 4'; \
    echo 'pm.min_spare_servers = 2'; \
    echo 'pm.max_spare_servers = 6'; \
    echo 'pm.max_requests = 500'; \
    echo 'request_terminate_timeout = 60s'; \
    echo 'catch_workers_output = yes'; \
  } >> /etc/php/8.5/fpm/pool.d/www.conf

# Add Baikal & nginx configuration
COPY files/docker-entrypoint.d/*.sh files/docker-entrypoint.d/*.php files/docker-entrypoint.d/nginx/ /docker-entrypoint.d/
COPY --from=builder --chown=nginx:nginx baikal /var/www/baikal
COPY files/nginx.conf /etc/nginx/conf.d/default.conf

VOLUME /var/www/baikal/config
VOLUME /var/www/baikal/Specific