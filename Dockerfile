FROM arm64v8/debian

LABEL maintainer="scepter@1949hacker.cn"

RUN rm /etc/apt/sources.list.d/debian.sources -f

RUN echo "deb http://mirrors.ustc.edu.cn/debian/ bookworm main contrib non-free non-free-firmware\
deb-src http://mirrors.ustc.edu.cn/debian/ bookworm main contrib non-free non-free-firmware\
deb http://mirrors.ustc.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware\
deb-src http://mirrors.ustc.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware\
deb http://mirrors.ustc.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware\
deb-src http://mirrors.ustc.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware\
deb http://mirrors.ustc.edu.cn/debian-security/ bookworm-security main contrib non-free non-free-firmware\
deb-src http://mirrors.ustc.edu.cn/debian-security/ bookworm-security main contrib non-free non-free-firmware" > /etc/apt/sources.list

RUN apt update -y && \
	apt install -y openssl netcat-openbsd vsftpd --no-install-recommends && \
	apt autoremove -y && apt clean -y && \
	rm -rf /var/lib/apt/lists/*

# VSFTPD configuration
COPY vsftpd.conf /etc/vsftpd.conf

# VSFTPD pre-configurations
COPY docker-entrypoint.sh /var/tmp/

RUN chmod +x /var/tmp/docker-entrypoint.sh

ENTRYPOINT ["/var/tmp/docker-entrypoint.sh"]

EXPOSE 20/tcp 21/tcp
EXPOSE 4559/tcp 4560/tcp 4561/tcp 4562/tcp 4563/tcp 4564/tcp

HEALTHCHECK --interval=5m --timeout=3s \
  CMD nc -z localhost 21 || exit 1

CMD ["vsftpd"]

# docker build -t 1949hacker/vsftpd:latest .
