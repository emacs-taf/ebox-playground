.DEFAULT_GOAL := check
.NOTPARALLEL:
EMACS ?= emacs
ECSS_DIR ?= ../ecss
LOAD_PATH = -L . -L lisp -L benchmarks -L ../ebox -L $(ECSS_DIR)
EBOX_NATIVE_RELEASE_DIR = $(shell $(EMACS) -Q --batch $(LOAD_PATH) \
	--eval '(setq native-comp-jit-compilation nil)' \
	-l ../ebox/ebox.el \
	--eval '(princ (expand-file-name (format "../ebox/native/target/%s/release/" (ebox-native-reflow--rust-target))))')

.PHONY: all compile check checkdoc load performance performance-prepare \
	performance-evaluator clean

all: check

compile:
	rm -f *.elc lisp/*.elc tests/*.elc examples/*.elc
	$(EMACS) -Q --batch $(LOAD_PATH) \
		--eval '(setq load-prefer-newer t native-comp-jit-compilation nil byte-compile-error-on-warn t)' \
		--eval '(load-file "ebox-playground.el")' \
		--eval '(dolist (file (quote ("lisp/ebox-playground-runtime.el" "ebox-playground.el"))) (unless (byte-compile-file file) (error "Compilation failed: %s" file)))' \
		--eval '(dolist (file (directory-files "examples" t)) (when (string-suffix-p ".el" file) (unless (byte-compile-file file) (error "Companion compilation failed: %s" file))))' \
		--eval '(unless (byte-compile-file "benchmarks/ebox-playground-flex-resize-evaluator.el") (error "Evaluator compilation failed"))'

load: compile
	$(EMACS) -Q --batch $(LOAD_PATH) \
		--eval '(setq native-comp-jit-compilation nil)' \
		--eval '(require (quote ebox-playground))' \
		--eval '(princ "ebox-playground load OK\n")'

performance:
	$(MAKE) performance-prepare EMACS="$(EMACS)" ECSS_DIR="$(ECSS_DIR)"
	$(MAKE) performance-evaluator EMACS="$(EMACS)" ECSS_DIR="$(ECSS_DIR)"

performance-prepare:
	$(MAKE) -C $(ECSS_DIR) compile EMACS="$(EMACS)"
	$(MAKE) -C ../ebox compile EMACS="$(EMACS)" ECSS_DIR="$(ECSS_DIR)"
	$(MAKE) compile EMACS="$(EMACS)" ECSS_DIR="$(ECSS_DIR)"
	$(MAKE) -C ../ebox native-build EMACS="$(EMACS)" ECSS_DIR="$(ECSS_DIR)"

performance-evaluator:
	EBOX_NATIVE_REFLOW_MODULE_PATH="$(EBOX_NATIVE_RELEASE_DIR)" \
	EMACS="$(EMACS)" ./benchmarks/flex-resize-evaluator.sh

checkdoc:
	$(EMACS) -Q --batch --eval '(progn (require (quote checkdoc)) (dolist (directory (quote ("." "examples"))) (dolist (file (directory-files directory t)) (when (string-suffix-p ".el" file) (checkdoc-file file)))))'

check: structure-check compile acceptance api-check tool-check

.PHONY: tool-check
tool-check:
	EMACS="$(EMACS)" python3 -m unittest discover -s tests/tools -p 'test_*.py'

clean:
	rm -f *.elc lisp/*.elc tests/*.elc examples/*.elc

.PHONY: structure-check setup-hooks
structure-check:
	python3 scripts/check-repository.py
setup-hooks:
	git config --local core.hooksPath .githooks

.PHONY: acceptance
acceptance:
	python3 scripts/run-acceptance.py --emacs "$(EMACS)"

.PHONY: api-check
api-check:
	$(EMACS) -Q --batch -L . $(API_PROVIDER_PATH) --eval '(setq load-prefer-newer t)' -l scripts/check-api.el
API_PROVIDER_PATH = -L ../ecss -L ../ekp -L ../ebox -L ../etaf -L ../etaf-ui -L ../etaf-db -L ../etaf-playground

.PHONY: test
test: acceptance
