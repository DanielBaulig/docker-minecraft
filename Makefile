PROJECT=minecraft
USERNAME=dbaulig
IMAGE=$(USERNAME)/$(PROJECT)
DOCKER=sudo docker

SHELL := /bin/bash

default: dist

dist: dist/$(PROJECT).tar

refs/latest: Dockerfile
	mkdir -p refs
	latest=$$($(DOCKER) build $$([ ! -e refs/latest ] && echo "--no-cache") -t $(IMAGE) . \
		|tee /dev/stderr >(\
			mcversion=$$(sed -rn 's/^Minecraft Version: (.+)$$/\1/p') &&\
			[ -n "$$mcversion" ] &&\
			echo $$mcversion >refs/mcversion\
		)\
		|sed -rn 's/Successfully built (.+)$$/\1/p'\
	) && [ -n "$$latest" ] && echo "$$latest" >$@;

refs/mcversion: refs/latest

dist/$(PROJECT).tar: refs/latest
	mkdir -p dist
	sudo docker save $(IMAGE) >dist/$(PROJECT).tar

tag: refs/mcversion
	$(DOCKER) tag $(IMAGE) $(IMAGE):$$(cat $<)

clean:
	rm -rf refs/*

dist-clean: clean
	rm -rf dist/*

run: refs/latest
	$(DOCKER) run --rm -itP $(IMAGE)

orphaned-clean:
	orphaned=$$(sudo docker images | grep "^<none>" | awk '{print $$3}');\
		[ -z "$$orphaned" ] && exit 0;\
		sudo docker rmi $$orphaned

.PHONY: clean dist-clean dist default orphaned-clean run tag
