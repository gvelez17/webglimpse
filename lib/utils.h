#ifndef _utils_h
#define _utils_h


/*-------------------------------------------------------------*/
/* function prototypes */
int call_socket(char *hostname, int portnum);


/*-------------------------------------------------------------*/
/* error stuff */
#define ERRBUF_SIZE 512


void error(char *errmsg);
extern char errbuf[];


#define ERROR0(a) error(a)
#define ERROR1(a, b) {sprintf(errbuf, a, b); error(errbuf);}
#define ERROR2(a, b, c) {sprintf(errbuf, a, b, c); error(errbuf);}
#define ERROR3(a, b, c, d) {sprintf(errbuf, a, b, c, d); error(errbuf);}
#define ERROR4(a, b, c, d, e) {sprintf(errbuf, a, b, c, d, e); error(errbuf);}

#endif
