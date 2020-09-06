FROM centos:7
LABEL maintainer="Daniil Silniahin"
ENV container docker
RUN yum install httpd -y
RUN ln -s /mnt/configuration /etc/httpd/conf.d/configuration
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]
EXPOSE 80
