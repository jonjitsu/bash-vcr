

.PHONY: run-tests run-linter

bats:
	git clone https://github.com/jonjitsu/bats.git || true

run-tests: bats
	docker run --rm -it \
		-v $$PWD:/project \
		-w /project \
		ubuntu bash /project/tests/run.sh

test-repl: bats
	docker run --rm -it \
		-v $$PWD:/project \
		-w /project \
		ubuntu bash /project/tests/run.sh repl

run-linter:
	docker network prune -f
	docker run --rm \
		-v $$PWD:/project \
		-w /project \
		koalaman/shellcheck \
		-Cauto -s bash  \
		tests/run.sh \
		mock.sh
