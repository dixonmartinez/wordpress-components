FROM php:7.2-apache

# install the PHP extensions we need
RUN set -ex; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libjpeg-dev \
		libpng-dev \
	; \
	\
	docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr; \
	docker-php-ext-install gd mysqli opcache zip; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN a2enmod rewrite expires


# Add wp cli
RUN curl -o /usr/local/bin/wp -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp


#VOLUME /var/www/html

ENV WORDPRESS_VERSION 4.9.8
ENV WORDPRESS_SHA1 0945bab959cba127531dceb2c4fed81770812b4f

RUN set -ex; \
	curl -o wordpress.tar.gz -fSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz"; \
	echo "$WORDPRESS_SHA1 *wordpress.tar.gz" | sha1sum -c -; \
# upstream tarballs include ./wordpress/ so this gives us /usr/src/wordpress
	#tar -xzf wordpress.tar.gz -C /usr/src/; \
	tar -xzf wordpress.tar.gz -C /var/www/html --strip-components=1; \
	rm wordpress.tar.gz; \
	rm -r /var/www/html/wp-content/plugins/akismet; \
	rm /var/www/html/wp-content/plugins/hello.php; \
	rm -r /var/www/html/wp-content/themes/twenty*; \
	#chown -R www-data:www-data /usr/src/wordpress
	chown -R www-data:www-data /var/www/html

COPY docker-entrypoint.sh /usr/local/bin/

COPY --chown=www-data:www-data .htaccess /var/www/html/

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]

# Custom content
# Tools
RUN apt-get update && apt-get install -y nano less

# WP Config
RUN mv /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini
RUN rm /usr/local/etc/php/php.ini-development

# WP Plugins
COPY --chown=www-data:www-data ./plugins /var/www/html/wp-content/plugins

# WP Themes
COPY --chown=www-data:www-data ./themes /var/www/html/wp-content/themes
