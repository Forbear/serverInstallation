FROM centos:7
LABEL maintainer="Daniil Silniahin"
ENV container docker
RUN yum install httpd mod_ssl -y -q
RUN sed -i 's/Options Indexes FollowSymLinks/Options -Indexes +FollowSymLinks/1' /etc/httpd/conf/httpd.conf
#RUN echo 'IncludeOptional conf.d/configuration/*.conf' >> /etc/httpd/conf/httpd.conf
RUN rm -r /etc/httpd/conf.d/
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]
EXPOSE 80
