FROM alpine:edge

RUN apk add --no-cache openconnect openssh 

# create the root user's .ssh directory and unlock the root account
RUN mkdir /root/.ssh \
    && chmod 0700 /root/.ssh \
    && sed -i 's/^root:!::0:::::/root:::0:::::/' /etc/shadow 

WORKDIR /vpn
COPY ./entrypoint.sh .
RUN chmod +x ./entrypoint.sh

COPY ./sshd_config /etc/ssh/

ENTRYPOINT ["/vpn/entrypoint.sh"]
