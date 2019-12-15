CC=gcc
FLEX=flex
BISON=bison
splc:
	make clean
	@mkdir bin
	$(FLEX) lex.l
	$(BISON) -t -d syntax.y
	$(CC) -w syntax.tab.c -lfl -ly -o bin/splc
	touch bin/splc
	@chmod +x bin/splc
debug:
	./bin/splc debug.spl
	cat -n debug.out
sample1:
	./bin/splc ./sample/test01.spl
	cat -n ./sample/test01.out
sample2:
	./bin/splc ./sample/test02.spl
	cat -n ./sample/test02.out
sample3:
	./bin/splc ./sample/test03.spl
	cat -n ./sample/test03.out
sample4:
	./bin/splc ./sample/test04.spl
	cat -n ./sample/test04.out
clean:
	@rm -rf bin/
	@rm -rf syntax.tab.*
	@rm -rf lex.yy.c
	@rm -rf syntax.output
.PHONY: splc