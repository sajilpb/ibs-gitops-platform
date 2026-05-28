# docker

helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update


helm install jaeger jaegertracing/jaeger \
  --namespace default \
  --set allInOne.enabled=true \
  --set collector.enabled=false \
  --set agent.enabled=false \
  --set query.enabled=false \
  --set storage.type=memory \
  --set storage.cassandra.enabled=false \
  --set cassandra.enabled=false \
  --set query.ingress.enabled=false \
  --set collector.ingress.enabled=false



