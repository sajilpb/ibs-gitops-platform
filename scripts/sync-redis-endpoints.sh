#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_JSON="$(terraform -chdir="$ROOT_DIR/terraform" output -json elasticache_redis_endpoints)"

export ROOT_DIR
export OUTPUT_JSON

ruby <<'RUBY'
require "json"
require "yaml"

root_dir = ENV.fetch("ROOT_DIR")
endpoints = JSON.parse(ENV.fetch("OUTPUT_JSON"))

env_files = {
  "dev" => "gitops/applications/development/values.yaml",
  "prod" => "gitops/applications/production/values.yaml"
}

env_files.each do |env, relative_path|
  endpoint = endpoints.fetch(env)
  path = File.join(root_dir, relative_path)
  values = YAML.load_file(path) || {}

  values["redis"] ||= {}
  values["redis"]["enabled"] = false
  values["redis"]["external"] ||= {}
  values["redis"]["external"]["enabled"] = true
  values["redis"]["external"]["host"] = endpoint.fetch("host")
  values["redis"]["external"]["port"] = endpoint.fetch("port")
  values["redis"]["external"]["scheme"] ||= "redis"

  File.write(path, YAML.dump(values).sub(/\A---\n/, ""))
  puts "Updated #{relative_path} -> #{endpoint.fetch("host")}:#{endpoint.fetch("port")}"
end
RUBY
