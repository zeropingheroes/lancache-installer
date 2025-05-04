#!/bin/bash

# Exit if there is an error
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# If script is executed as an unprivileged user
# Execute it as superuser, preserving environment variables
if [ $EUID != 0 ]; then
    sudo -E "$0" "$@"
    exit $?
fi

# If there is an .env file use it
# to set the variables
if [ -f $SCRIPT_DIR/.env ]; then
    source $SCRIPT_DIR/.env
fi

echo "Checking all required variables are set"
: "${CACHE_DATA_DIRECTORY:?must be set}"
: "${CACHE_LOGS_DIRECTORY:?must be set}"
: "${CACHE_TEMP_DIRECTORY:?must be set}"

echo "Installing required packages"
/usr/bin/apt update -y
/usr/bin/apt install -y libpcre3 \
                        libpcre3-dev \
                        build-essential

echo "Creating temporary directory for source code"
rm -rf /tmp/lancache-installer/
mkdir -p /tmp/lancache-installer/

echo "Downloading Nginx source"
/usr/bin/curl -#Lo /tmp/lancache-installer/nginx-1.28.0.tar.gz "http://nginx.org/download/nginx-1.28.0.tar.gz"

echo "Decompressing Nginx source"
tar xvzf /tmp/lancache-installer/nginx-1.28.0.tar.gz -C /tmp/lancache-installer/nginx-1.28.0

echo "Compiling Nginx"
cd /tmp/lancache-installer/nginx-1.28.0 && ./configure \
        --sbin-path=/usr/local/bin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --pid-path=/run/nginx.pid \
        --user=www-data \
        --with-stream \
        --with-stream_ssl_preread_module \
        --with-http_slice_module \
        --with-http_stub_status_module \
        --with-pcre \
        --with-file-aio \
        --with-threads \
        --without-http_ssi_module \
        --without-http_charset_module \
        --without-http_userid_module \
        --without-http_auth_basic_module \
        --without-http_geo_module \
        --without-http_split_clients_module \
        --without-http_referer_module \
        --without-http_fastcgi_module \
        --without-http_uwsgi_module \
        --without-http_scgi_module \
        --without-http_memcached_module \
        --without-http_limit_conn_module \
        --without-http_limit_req_module \
        --without-http_empty_gif_module \
        --without-http_upstream_hash_module \
        --without-http_upstream_ip_hash_module \
        --without-http_upstream_least_conn_module \
        --without-http_upstream_keepalive_module \
        --without-http_upstream_zone_module

cd /tmp/lancache-installer/nginx-1.28.0 && make -j $(nproc)
cd /tmp/lancache-installer/nginx-1.28.0 && make install

echo "Moving default Nginx config files to nginx.default"
mv /etc/nginx /etc/nginx.default

echo "Creating directories"
mkdir -p /etc/nginx
mkdir -p $CACHE_DATA_DIRECTORY
mkdir -p $CACHE_LOGS_DIRECTORY
mkdir -p $CACHE_TEMP_DIRECTORY

echo "Setting permissions for directories"
chown -R www-data:www-data $CACHE_DATA_DIRECTORY $CACHE_LOGS_DIRECTORY $CACHE_TEMP_DIRECTORY

echo "Getting nginx configuration files"
/usr/bin/git clone git@github.com:zeropingheroes/lancache.git /etc/nginx/

echo "Installing nginx service"
cp $SCRIPT_DIR/configs/systemd/nginx.service /lib/systemd/system/nginx.service

echo "Loading new service file"
/bin/systemctl daemon-reload

echo "Setting the nginx service to start at boot"
/bin/systemctl enable nginx

echo "Starting the nginx service"
/bin/systemctl start nginx
