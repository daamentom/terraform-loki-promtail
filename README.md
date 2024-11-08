commands om met localstack te testen:
indien localstack geinstalleerd is
- localstack start


- tflocal plan
- tflocal apply

- tflocal destroy


eigen custom docker image waarbij de promtail configuratie wordt meegegeven.

FROM grafana/promtail

COPY config/config.yml /etc/promtail/config.yml

en de config.yml uit deze project wordt daarbij gebruikt.

uiteindelijk dit bijhouden voor ECR