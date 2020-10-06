FROM php:7.2-fpm-stretch

MAINTAINER sadoknet@gmail.com
ENV DEBIAN_FRONTEND=noninteractive

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.22.1.0/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

RUN \
  	apt-get -y update && \
  	apt-get -y install --no-install-recommends \
  	nginx zip unzip\
	imagemagick webp libmagickwand-dev libyaml-dev \
	python3 python3-numpy libopencv-dev python3-setuptools opencv-data \
    gcc nasm build-essential make wget vim git && \
    rm -rf /var/lib/apt/lists/*

#opcache
RUN docker-php-ext-install opcache

RUN pecl install imagick yaml-2.0.0 && \
    echo "extension=imagick.so" > /usr/local/etc/php/conf.d/imagick.ini && \
    echo "extension=yaml.so" > /usr/local/etc/php/conf.d/yaml.ini && \
    echo "expose_php=off" > /usr/local/etc/php/conf.d/expose_php.ini

#install MozJPEG
RUN \
    wget "https://github.com/mozilla/mozjpeg/releases/download/v3.2/mozjpeg-3.2-release-source.tar.gz" && \
    tar xvf "mozjpeg-3.2-release-source.tar.gz" && \
    rm mozjpeg-3.2-release-source.tar.gz && \
    cd mozjpeg && \
    ./configure && \
    make && \
    make install

#facedetect script
RUN \
	cd /var && \
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3 get-pip.py && \
    pip3 install numpy && \
    pip3 install opencv-python && \
    git clone https://github.com/flyimg/facedetect.git && \
    chmod +x /var/facedetect/facedetect && \
    ln -s /var/facedetect/facedetect /usr/local/bin/facedetect

#Smart Cropping pytihon plugin
RUN pip install git+https://github.com/flyimg/python-smart-crop

#composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

#disable output access.log to stdout
RUN sed -i -e 's#access.log = /proc/self/fd/2#access.log = /proc/self/fd/1#g'  /usr/local/etc/php-fpm.d/docker.conf

#copy etc/
COPY resources/etc/ /etc/

ENV PORT 80

COPY resources/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

RUN rm -rf /var/www/html/*

COPY grouperg-flyimg/bin/ /var/www/html/bin/
COPY grouperg-flyimg/config/ /var/www/html/config/
COPY grouperg-flyimg/public/ /var/www/html/public/
COPY grouperg-flyimg/src/ /var/www/html/src/
COPY grouperg-flyimg/templates/ /var/www/html/templates/
COPY grouperg-flyimg/composer.json /var/www/html/composer.json
COPY grouperg-flyimg/composer.lock /var/www/html/composer.lock
COPY grouperg-flyimg/symfony.lock /var/www/html/symfony.lock

RUN echo 'APP_ENV="dev"' >/var/www/html/.env \
    && echo 'APP_SECRET="b713788cc9b60cfb9f0230ef846c6ebe"' >> /var/www/html/.env

RUN chmod +x /var/www/html/bin/console

RUN cd /var/www/html/ \
    && composer install

WORKDIR /var/www/html

ENTRYPOINT ["docker-entrypoint", "/init"]

