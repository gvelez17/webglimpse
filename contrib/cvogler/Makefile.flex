htuml2txt: lex.yy.c
	cc -O -o htuml2txt lex.yy.c -lfl

lex.yy.c: htuml2txt.lex
	flex -F -8 htuml2txt.lex

clean:
	rm -f *.o lex.yy.c core
