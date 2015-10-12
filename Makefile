BUILDDIR=_build
VPATH=$(BUILDDIR)
OCAMLDIR=$(shell ocamlopt -where)
$(shell mkdir -p $(BUILDDIR) $(BUILDDIR)/lib $(BUILDDIR)/stub_generator $(BUILDDIR)/test $(BUILDDIR)/generated)
PACKAGES=irmin.mem,ctypes.stubs,ctypes.foreign,lwt.unix

# The files used to build the stub generator.
GENERATOR_FILES=$(BUILDDIR)/lib/bindings.cmx		\
                $(BUILDDIR)/stub_generator/generate.cmx

# The files from which we'll build a shared library.
LIBFILES=$(BUILDDIR)/lib/bindings.cmx			\
         $(BUILDDIR)/generated/irmin_bindings.cmx	\
         $(BUILDDIR)/lib/apply_bindings.cmx		\
         $(BUILDDIR)/generated/irmin.o

# The files that we'll generate
GENERATED=$(BUILDDIR)/generated/irmin.h \
          $(BUILDDIR)/generated/irmin.c \
          $(BUILDDIR)/generated/irmin_bindings.ml

GENERATOR=$(BUILDDIR)/generate

all: sharedlib

sharedlib: $(BUILDDIR)/libirmin.so

$(BUILDDIR)/libirmin.so: $(LIBFILES)
	ocamlfind opt -o $@ -linkpkg -output-obj -runtime-variant _pic  -package $(PACKAGES) $^

stubs: $(GENERATED)

$(GENERATED): $(GENERATOR)
	$(BUILDDIR)/generate $(BUILDDIR)/generated

$(BUILDDIR)/%.o: %.c
	gcc -c -o $@ -fPIC -I $(BUILDDIR) -I $(OCAMLDIR) -I $(OCAMLDIR)/../ctypes $<

$(BUILDDIR)/%.cmx: %.ml
	ocamlfind opt -c -o $@ -I $(BUILDDIR)/generated -I $(BUILDDIR)/lib -package $(PACKAGES) $<

$(GENERATOR): $(GENERATOR_FILES)
	ocamlfind opt -o $@ -linkpkg -package $(PACKAGES) $^

clean:
	rm -rf $(BUILDDIR)

test: all
	$(MAKE) -C $@
	LD_LIBRARY_PATH=$(BUILDDIR) _build/test/test.native test/ocaml.svg

$(BUILDDIR)/generated/irmin.c: irmin.h

$(BUILDDIR)/irmin.h: lib/irmin.h
	cp $< $(BUILDDIR)

.PHONY: test
