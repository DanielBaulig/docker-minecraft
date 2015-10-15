PROJECT=
USERNAME=
IMAGE=$(USERNAME)/$(PROJECT)
DOCKER=sudo docker

default: dist

dist: dist/$(PROJECT).tar

refs/latest: Dockerfile
	mkdir -p refs
	latest=$$($(DOCKER) build $$([ ! -e refs/latest ] && echo "--no-cache") -t $(IMAGE) . \
		|tee /dev/stderr
		|sed -rn 's/Successfully built (.+)$$/\1/p'\
	) && [ -n "$$latest" ] && echo "$$latest" >$@;

dist/$(PROJECT).tar: refs/latest
	mkdir -p dist
	sudo docker save $(IMAGE) >dist/$(PROJECT).tar

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

.PHONY: clean dist-clean dist default orphaned-clean run
