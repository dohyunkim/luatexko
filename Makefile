NAME		= luatexko
TEXFILE		= $(NAME)-doc.tex
PDFFILE		= $(NAME)-doc.pdf
RUNFILES	= $(wildcard $(NAME)*.sty) $(wildcard $(NAME)*.lua)
DOCFILES	= $(TEXFILE) $(PDFFILE) README ChangeLog
ZIPFILE		= $(NAME).zip
DO_LATEX	= texfot --quiet --ignore "Marginpar on page \d+ moved" --tee=/dev/null lualatex-dev $(TEXFILE)
FORMAT		= luatex
RUNDIR		= $(TEXMFDIR)/tex/$(FORMAT)/$(NAME)
DOCDIR		= $(TEXMFDIR)/doc/$(FORMAT)/$(NAME)
TEXMFDIR	= $(shell kpsewhich --var-value TEXMFHOME)
MYTMPFILE	= texfot.XXXXX

all: doc ctan

doc: $(PDFFILE)

$(PDFFILE): $(TEXFILE) $(RUNFILES)
	@$(DO_LATEX) | tee $(MYTMPFILE)
	@if( grep Rerun $(MYTMPFILE) > /dev/null ); then $(DO_LATEX); fi
	@$(RM) $(MYTMPFILE)

ctan: $(ZIPFILE)

$(ZIPFILE): $(RUNFILES) $(DOCFILES)
	@$(RM) $@
	@mkdir -p $(NAME) && cp $^ $(NAME)
	@zip -q -r -9 $@ $(NAME) && ls -l $@
	@$(RM) -r $(NAME)

install: $(RUNFILES) $(DOCFILES)
	@echo Installing into: $(TEXMFDIR)
	@mkdir -p $(RUNDIR) && cp $(RUNFILES) $(RUNDIR)
	@mkdir -p $(DOCDIR) && cp $(DOCFILES) $(DOCDIR)

uninstall:
	@echo Uninstalling from: $(TEXMFDIR)
	@$(RM) -r $(RUNDIR) $(DOCDIR)
