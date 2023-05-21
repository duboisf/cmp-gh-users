
test:
	@nvim --headless --noplugin -u tests/minimal_init.vim \
		-c "PlenaryBustedDirectory tests/cmp-gh-users/ {minimal_init = 'tests/minimal_init.vim', timeout=2000}"
