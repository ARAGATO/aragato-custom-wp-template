#!/usr/bin/env bash
# Provision WordPress Stable

DOMAIN=`get_primary_host "${VVV_SITE_NAME}".test`
DOMAINS=`get_hosts "${DOMAIN}"`
SITE_TITLE=`get_config_value 'site_title' "${DOMAIN}"`
WP_VERSION=`get_config_value 'wp_version' 'latest'`
WP_TYPE=`get_config_value 'wp_type' "single"`
DB_NAME=`get_config_value 'db_name' "${VVV_SITE_NAME}"`
DB_NAME=${DB_NAME//[\\\/\.\<\>\:\"\'\|\?\!\*-]/}

# Make a database, if we don't already have one
echo -e "\nCreating database '${DB_NAME}' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e "\n DB operations done.\n\n"

# Nginx Logs
mkdir -p ${VVV_PATH_TO_SITE}/log
touch ${VVV_PATH_TO_SITE}/log/error.log
touch ${VVV_PATH_TO_SITE}/log/access.log

# Install and configure the latest stable version of WordPress
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-load.php" ]]; then
    echo "Downloading WordPress..."
	noroot wp core download --version="${WP_VERSION}"
fi

if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-config.php" ]]; then
  echo "Configuring WordPress Stable..."
  noroot wp core config --dbname="${DB_NAME}" --dbuser=wp --dbpass=wp --quiet --extra-php <<PHP
define( 'WP_DEBUG', true );
PHP
fi

if ! $(noroot wp core is-installed); then
  echo "Installing WordPress Stable..."

  if [ "${WP_TYPE}" = "subdomain" ]; then
    INSTALL_COMMAND="multisite-install --subdomains"
  elif [ "${WP_TYPE}" = "subdirectory" ]; then
    INSTALL_COMMAND="multisite-install"
  else
    INSTALL_COMMAND="install"
  fi

  noroot wp core ${INSTALL_COMMAND} --url="${DOMAIN}" --quiet --title="${SITE_TITLE}" --admin_name=admin --admin_email="admin@local.test" --admin_password="password"
else
  echo "Updating WordPress Stable..."
  cd ${VVV_PATH_TO_SITE}/public_html
  noroot wp core update --version="${WP_VERSION}"
fi

## ARAGATO CUSTOM CODE - START ##

# Update options
wp option update --allow-root --quiet blogdescription ''
wp option update --allow-root --quiet start_of_week 1
wp option update --allow-root --quiet timezone_string 'Europe/Berlin'
wp option update --allow-root --quiet permalink_structure '/%postname%/'
wp option update --allow-root --quiet admin_email admin@aragato.com
wp option update --allow-root --quiet date_format 'd.m.Y'
wp option update --allow-root --quiet time_format 'H:i'
wp option update --allow-root --quiet gzipcompression 1
wp option update --allow-root --quiet enable_xmlrpc 0

# Language settings
wp language core install --allow-root --quiet de_DE
wp language core activate --allow-root --quiet de_DE

# Delete unneeded default themes and plugins
wp theme delete --allow-root --quiet twentytwelve
wp theme delete --allow-root --quiet twentythirteen
wp theme delete --allow-root --quiet twentyfourteen
wp theme delete --allow-root --quiet twentyfifteen
wp theme delete --allow-root --quiet twentysixteen
wp plugin delete --allow-root --quiet hello
wp plugin delete --allow-root --quiet akismet
wp post --allow-root --quiet delete 1
wp post --allow-root --quiet delete 2
wp post --allow-root --quiet delete 3

# Get plugins
wp plugin install --allow-root --quiet a3-lazy-load
wp plugin install --allow-root --quiet admin-menu-editor
wp plugin install --allow-root --quiet adminimize
wp plugin install --allow-root --quiet advanced-custom-fields
wp plugin install --allow-root --quiet better-wp-security
wp plugin install --allow-root --quiet bnfw
wp plugin install --allow-root --quiet cookie-notice
wp plugin install --allow-root --quiet css-javascript-toolbox
wp plugin install --allow-root --quiet custom-login-logo
wp plugin install --allow-root --quiet duplicate-post --activate
wp plugin install --allow-root --quiet force-regenerate-thumbnails --activate
wp plugin install --allow-root --quiet hh-sortable --activate
wp plugin install --allow-root --quiet iwp-client
wp plugin install --allow-root --quiet loco-translate
wp plugin install --allow-root --quiet my-custom-functions --activate
wp plugin install --allow-root --quiet nk-google-analytics
wp plugin install --allow-root --quiet quick-and-easy-faqs
wp plugin install --allow-root --quiet redirection
wp plugin install --allow-root --quiet ssl-insecure-content-fixer
wp plugin install --allow-root --quiet stealth-login-page
wp plugin install --allow-root --quiet stops-core-theme-and-plugin-updates
wp plugin install --allow-root --quiet taxonomy-terms-order --activate
wp plugin install --allow-root --quiet the-events-calendar
wp plugin install --allow-root --quiet tinymce-advanced
wp plugin install --allow-root --quiet uji-popup
wp plugin install --allow-root --quiet user-role-editor
wp plugin install --allow-root --quiet velvet-blues-update-urls
wp plugin install --allow-root --quiet w3-total-cache
wp plugin install --allow-root --quiet wordpress-php-info --activate
wp plugin install --allow-root --quiet wordpress-seo
wp plugin install --allow-root --quiet wp-crontrol
wp plugin install --allow-root --quiet wp-mail-smtp
wp plugin install --allow-root --quiet wp-slimstat
wp plugin install --allow-root --quiet wp-staging

## ARAGATO CUSTOM CODE - END ##

cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf.tmpl" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
sed -i "s#{{DOMAINS_HERE}}#${DOMAINS}#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"

if [ -n "$(type -t is_utility_installed)" ] && [ "$(type -t is_utility_installed)" = function ] && `is_utility_installed core tls-ca`; then
    sed -i "s#{{TLS_CERT}}#ssl_certificate /vagrant/certificates/${VVV_SITE_NAME}/dev.crt;#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
    sed -i "s#{{TLS_KEY}}#ssl_certificate_key /vagrant/certificates/${VVV_SITE_NAME}/dev.key;#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
else
    sed -i "s#{{TLS_CERT}}##" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
    sed -i "s#{{TLS_KEY}}##" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
fi
