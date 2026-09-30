.PHONY: assemble render verify

assemble:
	bash scripts/assemble_manuscript.sh

render: assemble
	bash scripts/render_manuscript.sh

verify: assemble
	python3 scripts/check_citations.py manuscript/combined_manuscript.md manuscript/references.bib
