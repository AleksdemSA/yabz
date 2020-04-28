FROM ubuntu:18.04

RUN apt update && apt install -y curl
RUN curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.deb.sh | bash
RUN apt -y install sysbench

ADD init.sh /

CMD ["/init.sh"]
