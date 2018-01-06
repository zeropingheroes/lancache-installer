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

# Install required packages
/usr/bin/apt update -y
/usr/bin/apt install -y ioping \
                        sysstat \
                        lm-sensors \
                        build-essential \
                        make \
                        python \
                        python-pip

# Make temporary directory for source code
rm -rf /tmp/lancache-installer/
mkdir -p /tmp/lancache-installer/

# Get required source code archives
/usr/bin/curl -#Lo /tmp/lancache-installer/LuaJIT-2.0.5.tar.gz "http://luajit.org/download/LuaJIT-2.0.5.tar.gz"
/usr/bin/curl -#Lo /tmp/lancache-installer/lua-nginx-module-0.10.11.tar.gz "https://github.com/openresty/lua-nginx-module/archive/v0.10.11.tar.gz"
/usr/bin/curl -#Lo /tmp/lancache-installer/nginx-1.12.2.tar.gz "http://nginx.org/download/nginx-1.12.2.tar.gz"
/usr/bin/curl -#Lo /tmp/lancache-installer/ngx_devel_kit-0.3.0.tar.gz "https://github.com/simpl/ngx_devel_kit/archive/v0.3.0.tar.gz"
/usr/bin/curl -#Lo /tmp/lancache-installer/pcre-8.41.tar.gz "http://downloads.sourceforge.net/project/pcre/pcre/8.41/pcre-8.41.tar.gz"

# Uncompress all source code archives
for archive in /tmp/lancache-installer/*.tar.gz; do tar xvzf $archive -C /tmp/lancache-installer/; done

# Compile LuaJIT
cd /tmp/lancache-installer/LuaJIT-2.0.5 && make -j 8 PREFIX="/tmp/lancache-installer/LuaJIT-2.0.5/compiled"
cd /tmp/lancache-installer/LuaJIT-2.0.5 && make install PREFIX="/tmp/lancache-installer/LuaJIT-2.0.5/compiled"

# Compile PCRE
cd /tmp/lancache-installer/pcre-8.41 && ./configure
cd /tmp/lancache-installer/pcre-8.41 && make -j 8
cd /tmp/lancache-installer/pcre-8.41 && make install

# Tell nginx's build system where LuaJIT is
export LUAJIT_LIB=/tmp/lancache-installer/LuaJIT-2.0.5/compiled/lib
export LUAJIT_INC=/tmp/lancache-installer/LuaJIT-2.0.5/compiled/include/luajit-2.0

# Compile nginx
cd /tmp/lancache-installer/nginx-1.12.2 && ./configure \
        --sbin-path=/usr/local/bin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --pid-path=/run/nginx.pid \
        --user=www-data \
        --with-stream \
        --with-http_slice_module \
        --with-http_stub_status_module \
        --with-ld-opt="-Wl,-rpath,/usr/local/lib" \
        --with-pcre="/tmp/lancache-installer/pcre-8.41" \
        --add-module="/tmp/lancache-installer/ngx_devel_kit-0.3.0" \
        --add-module="/tmp/lancache-installer/lua-nginx-module-0.10.11" \
        --without-http_gzip_module \
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

cd /tmp/lancache-installer/nginx-1.12.2 && make -j 8
cd /tmp/lancache-installer/nginx-1.12.2 && make install

# Remove default nginx config files
rm -rf /etc/nginx

# Create directories for cache
mkdir -p /etc/nginx
mkdir -p /var/lancache/cache/installers
mkdir -p /var/lancache/cache/tmp
mkdir -p /var/lancache/logs/

# Set correct permissions for directories
chown -R www-data:www-data /var/lancache

# Get the lancache nginx configuration files
/usr/bin/git clone https://github.com/zeropingheroes/lancache.git /etc/nginx/

# Install nginx servce
cp $SCRIPT_DIR/configs/systemd/nginx.service /lib/systemd/system/nginx.service

# Load the new service file
/bin/systemctl daemon-reload

# Set the nginx service to start at boot
/bin/systemctl enable nginx

# Start the nginx service
/bin/systemctl start nginx
