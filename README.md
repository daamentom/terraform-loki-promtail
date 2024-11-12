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

172.17.0.4 bij grafana voor data connectie met loki

om te testen in de promtail container:

docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 51f7f388f37c     
(loki contianer-id)

nodelogger heeft package.json nodig om gebuild te worden.

