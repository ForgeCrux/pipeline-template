#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

REPO_DIR="gitops-repo"
OWNER="${GITHUB_REPOSITORY_OWNER:-}"
SERVICE="${SERVICE_NAME}"
BRANCH="${GITOPS_REPO_BRANCH:-main}"

_repo_url_from_env() {
  if [ -n "${GITOPS_REPO_URL:-}" ]; then
    echo "$GITOPS_REPO_URL"
  else
    echo "https://github.com/${OWNER}/${SERVICE}-gitops.git"
  fi
}

_create_repo_if_missing() {
  local url="$1"
  if [ -n "${GITOPS_REPO_URL:-}" ]; then
    echo "Using existing ops repo: $url"
    return 0
  fi

  local repo_name="${SERVICE}-gitops"
  echo "Creating ops repo: ${OWNER}/${repo_name}"

  local status
  status="$(curl -sS -o /tmp/create-repo.json -w "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer ${GH_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/orgs/${OWNER}/repos" \
    -d "{\"name\":\"${repo_name}\",\"private\":true,\"auto_init\":true}")"

  if [ "$status" = "201" ]; then
    echo "Created new ops repo"
  elif [ "$status" = "422" ]; then
    echo "Ops repo already exists; using it"
  else
    echo "ERROR creating ops repo (HTTP $status):"
    cat /tmp/create-repo.json
    return 1
  fi
}

_clone_repo() {
  local url="$1"
  rm -rf "$REPO_DIR"
  local authed
  authed="$(echo "$url" | sed "s#https://#https://x-access-token:${GH_TOKEN}@#")"
  git clone --branch "$BRANCH" "$authed" "$REPO_DIR" 2>/dev/null \
    || git clone "$authed" "$REPO_DIR"
  cd "$REPO_DIR"
  git checkout -B "$BRANCH"
}

_scaffold_chart() {
  local chart_dir="charts/${SERVICE}"
  if [ -d "$chart_dir" ]; then
    echo "Chart exists at $chart_dir"
    return 0
  fi

  echo "Scaffolding chart at $chart_dir"
  mkdir -p "$chart_dir/templates"

  cat > "$chart_dir/Chart.yaml" <<EOF
apiVersion: v2
name: ${SERVICE}
description: Helm chart for ${SERVICE}
type: application
version: 0.1.0
appVersion: "${IMAGE_TAG}"
EOF

  cat > "$chart_dir/values.yaml" <<EOF
replicaCount: ${REPLICA_COUNT:-2}
image:
  repository: ${REGISTRY_URL}/${SERVICE}
  tag: "${IMAGE_TAG}"
  pullPolicy: IfNotPresent
service:
  type: ClusterIP
  port: 80
  targetPort: 8080
healthCheck:
  path: ${HEALTH_CHECK_PATH:-/health}
resources: {}
EOF

  cat > "$chart_dir/templates/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  labels:
    app: {{ .Release.Name }}
    version: {{ .Values.image.tag | quote }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
        - name: app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.targetPort }}
          livenessProbe:
            httpGet:
              path: {{ .Values.healthCheck.path }}
              port: {{ .Values.service.targetPort }}
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: {{ .Values.healthCheck.path }}
              port: {{ .Values.service.targetPort }}
            initialDelaySeconds: 10
            periodSeconds: 5
EOF

  cat > "$chart_dir/templates/service.yaml" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
  labels:
    app: {{ .Release.Name }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app: {{ .Release.Name }}
  ports:
    - protocol: TCP
      port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
EOF
}

_update_image_tag() {
  local values="charts/${SERVICE}/values.yaml"
  echo "Updating $values to tag ${IMAGE_TAG}"

  # Replace `tag:` line under `image:` — portable across awk versions.
  awk -v tag="  tag: \"${IMAGE_TAG}\"" '
    /^image:/     { in_image = 1; print; next }
    in_image && /^  tag:/  { print tag; next }
    in_image && /^[^ ]/    { in_image = 0 }
    { print }
  ' "$values" > "$values.new"
  mv "$values.new" "$values"
}

_commit_and_push() {
  git config user.email "ci-bot@forgesphere.local"
  git config user.name  "ForgeSphere CI"
  git add .
  if git diff --cached --quiet; then
    echo "No changes to commit"
  else
    git commit -m "Update ${SERVICE} image to ${IMAGE_TAG}"
    git push origin "$BRANCH"
  fi
}

_gitops_body() {
  local url; url="$(_repo_url_from_env)"
  _create_repo_if_missing "$url"
  _clone_repo "$url"
  _scaffold_chart
  _update_image_tag
  _commit_and_push

  echo "repo_url=$url" >> "$GITHUB_OUTPUT"
  echo "repo_branch=$BRANCH" >> "$GITHUB_OUTPUT"
}

stage_run GITOPS "GitOps Repository" _gitops_body