FROM centos:7 as proxy_point
LABEL maintainer="Daniil Silniahin"
ENV container docker
RUN yum install httpd mod_ssl -y -q
RUN sed -i 's/Options Indexes FollowSymLinks/Options -Indexes +FollowSymLinks/1' /etc/httpd/conf/httpd.conf
RUN echo "ServerTokens Prod" >> /etc/httpd/conf/httpd.conf
RUN rm -r /etc/httpd/conf.d/
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]
EXPOSE 80

FROM centos:7 as hiden_point
LABEL maintainer="Daniil Silniahin"
ENV container docker
RUN yum install httpd mod_ssl mod_security -y -q
RUN sed -i 's/Options Indexes FollowSymLinks/Options -Indexes +FollowSymLinks/1' /etc/httpd/conf/httpd.conf
RUN echo "ServerTokens Prod" >> /etc/httpd/conf/httpd.conf
RUN rm -r /etc/httpd/conf.d/
WORKDIR /var/www/html/
COPY content/index.html .
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]

FROM scratch as base
LABEL maintainer="Daniil Silniahin"
CMD ["NULL"]
