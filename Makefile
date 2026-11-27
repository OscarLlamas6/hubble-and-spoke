# =============================================================================
# Makefile — alias de compatibilidad. La fuente de verdad es Taskfile.yml.
# Existe para quien tenga memoria muscular de `make`: cada target delega en task.
# =============================================================================
.PHONY: help up down check-deps join-clusters install-crossplane install-gateway deploy-example test

help:               ; @task --list
up:                 ; @task up
down:               ; @task down
check-deps:         ; @task check-deps
join-clusters:      ; @task submariner
install-crossplane: ; @task crossplane api
install-gateway:    ; @task gateway
deploy-example:     ; @task example:apply
test:               ; @task test
