FROM phusion/baseimage:0.9.15
MAINTAINER Nathan Hopkins <natehop@gmail.com>

#RUN echo deb http://archive.ubuntu.com/ubuntu $(lsb_release -cs) main universe > /etc/apt/sources.list.d/universe.list
RUN apt-get -y update\
 && apt-get -y upgrade

# dependencies
RUN apt-get -y --force-yes install vim\
 apache2-mpm-worker\
 libapache2-mod-wsgi\
 python-dev\
 python-flup\
 python-pip\
 expect\
 memcached\
 git\
 sqlite3\
 libcairo2\
 libcairo2-dev\
 python-cairo\
 pkg-config\
 nodejs

# python dependencies
RUN pip install django==1.4.8\
 django-tagging==0.3.1\
 python-memcached==1.53\
 whisper==0.9.12\
 twisted==11.1.0\
 txAMQP==0.6.2

# install graphite
RUN git clone -b 0.9.12 https://github.com/graphite-project/graphite-web.git /usr/local/src/graphite-web
WORKDIR /usr/local/src/graphite-web
RUN python ./setup.py install
ADD scripts/local_settings.py /opt/graphite/webapp/graphite/local_settings.py
ADD conf/graphite/ /opt/graphite/conf/

# install whisper
RUN git clone -b 0.9.12 https://github.com/graphite-project/whisper.git /usr/local/src/whisper
WORKDIR /usr/local/src/whisper
RUN python ./setup.py install

# install carbon
RUN git clone -b 0.9.12 https://github.com/graphite-project/carbon.git /usr/local/src/carbon
WORKDIR /usr/local/src/carbon
RUN python ./setup.py install

# install statsd
RUN git clone -b v0.7.2 https://github.com/etsy/statsd.git /opt/statsd
ADD conf/statsd/config.js /opt/statsd/config.js

# config nginx
#RUN rm /etc/nginx/sites-enabled/default
#ADD conf/nginx/nginx.conf /etc/nginx/nginx.conf
#ADD conf/nginx/graphite.conf /etc/nginx/sites-available/graphite.conf
#RUN ln -s /etc/nginx/sites-available/graphite.conf /etc/nginx/sites-enabled/graphite.conf

# config apache2
RUN rm /etc/apache2/sites-enabled/000-default.conf
ADD conf/apache2/001-graphite.conf /etc/apache2/sites-available/001-graphite.conf
RUN ln -s /etc/apache2/sites-available/001-graphite.conf /etc/apache2/sites-enabled/001-graphite.conf
# init django admin
ADD scripts/django_admin_init.exp /usr/local/bin/django_admin_init.exp
RUN LANG="en_US.UTF-8" /usr/local/bin/django_admin_init.exp
RUN chown www-data:www-data /opt/graphite/storage/graphite.db

# logging support
RUN mkdir -p /var/log/carbon /var/log/graphite /var/log/apache2
#RUN chown www-data:www-data /var/log/graphite
RUN chown www-data:www-data -R /opt/*
ADD conf/logrotate /etc/logrotate.d/graphite

# daemons
ADD daemons/carbon.sh /etc/service/carbon/run
ADD daemons/carbon-aggregator.sh /etc/service/carbon-aggregator/run
ADD daemons/graphite.sh /etc/service/graphite/run
ADD daemons/statsd.sh /etc/service/statsd/run
ADD daemons/apache2.sh /etc/service/apache2/run

# cleanup
RUN apt-get clean\
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# defaults
EXPOSE 80:80 2003:2003 8125:8125/udp
VOLUME ["/opt/graphite", "/etc/nginx", "/opt/statsd", "/etc/logrotate.d"]
ENV HOME /root
CMD ["/sbin/my_init"]
