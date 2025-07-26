MARKDOWN_FILE = paper.md
TEX_FILE = paper.tex
PDF_FILE = paper.pdf
BIB_FILE = paper.bib

.PHONY: all clean watch

all: $(PDF_FILE)

$(TEX_FILE): $(MARKDOWN_FILE) preamble.tex $(BIB_FILE)
	pandoc $(MARKDOWN_FILE) -o $(TEX_FILE) \
		--standalone \
		--include-in-header=preamble.tex \
		--variable documentclass=IEEEtran \
		--variable classoption=conference \
		--variable fontsize=11pt \
		--variable papersize=a4paper \
		--citeproc \
		--csl=https://raw.githubusercontent.com/citation-style-language/styles/master/ieee.csl \
		--bibliography=$(BIB_FILE)

$(PDF_FILE): $(TEX_FILE)
	latexmk -pdf $(TEX_FILE)

watch:
	latexmk -pdf -pvc $(TEX_FILE)

clean:
	latexmk -C
	rm -f $(TEX_FILE)