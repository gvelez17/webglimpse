#include <stdio.h>

main()
{
        int    c;

while(1) {
        c=getchar();
        if (c==EOF) exit(1);
        if (c != '<') putchar(c);
        else 
                while (c != '>') {
                        c=getchar();
                        if (c==EOF) exit(1);
                }
        }
}
