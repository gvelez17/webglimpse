#include <errno.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/param.h>
#include <sys/time.h>
#if _AIX
#include <sys/select.h>
#endif
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <signal.h>
#include "utils.h"

/*
#define DEBUG
#define RAWGET
*/

#ifndef USERID
#define USERID "glimpse@cs.arizona.edu"
#endif

#define APPNAME "HTTPGET/1.0 GlimpseHTTP/3.0"

/* Macro which finds out length of base64 encoding of 'length' characters.  */
#define BASE64_LENGTH(length) (4 * (((length) + 2) / 3))

/* prototypes */
int get_url(char *url, FILE *outfile);

char *useraddr=USERID;
char *appname=APPNAME;
char *username, *password; /* 11/18/1999 - VG */
char *httpdate; /* 3/30/2000 - VG */
fd_set readset;
struct timeval timeout;
#define TIMEOUT_SEC 30
#define TIMEOUT_USEC 0
#define MAX_HEADER_LINES 1000		/* can run into buggy data streams in header or main file*/
#define MAX_FILE_SIZEK 100000		/* will not get more than 100Mb files in case of endless data stream*/

int max_time=30;
int inter_time=10;

int printheaders = 0;


char errbuf[ERRBUF_SIZE];

/*----------------------------------------------------------------------*/
void alarm_handler (int a){
	/* timeout! */
	ERROR0("Timeout.");
}

/*----------------------------------------------------------------------*/
/* generic error routine */
void error(char *errmsg){
   fprintf(stdout, "ERROR: %s\n", errmsg);
	exit(-100);
}

/*-----------------------------------------------------------------------*/
int wait_for_select(int s){
	int selrc;

	selrc=select(s+1, &readset, NULL, NULL, &timeout);

	if(selrc==0){
		ERROR0("select (inter-arrival) timeout");
	}else if(selrc<0){
		ERROR0("socket error");
	}
	return selrc;
}

/*-----------------------------------------------------------------------*/
int anychars(char *name){
	int namesize = strlen(name);
	int i;

	for(i=0; i<namesize; i++){
		if(isalpha(name[i])) return 1;
	}
	return 0;
}

/*-----------------------------------------------------------------------*/
int call_socket(char *hostname, int portnum){ 
	struct sockaddr_in sa;
	struct hostent     *hp;
	int s;
	int on=1;

	/* if the host has any characters in it, call gethostbyname */
	if (anychars(hostname)){
		if ((hp= gethostbyname(hostname)) == NULL) { /* do we know the host's */
			errno= ECONNREFUSED;                       /* address? */
			ERROR1("Cannot get host by name for %s.", hostname);
			return(-1);                                /* no */
		}
	}else{
		unsigned int addr = inet_addr(hostname);

		if ((hp= gethostbyaddr((void *)&addr,sizeof(addr), AF_INET)) == NULL) 
		{ /* do we know the host's */
			errno= ECONNREFUSED;                       /* address? */
			ERROR1("Cannot get host by address for %s.", hostname);
			return(-1);                                /* no */
		}
	}

/****************************************************************/
/*	In earlier version of solaris, bzero is only supported	*/
/*	in BSD compatible library.				*/
/*	So we change bzero to memset, bcopy to memcpy.		*/
/*								*/
/*			Dachuan Zhang, June 1st, 1996.		*/
/****************************************************************/

	memset((char *)&sa, 0, sizeof(sa));
	memcpy((char *)&sa.sin_addr, hp->h_addr, hp->h_length);
	sa.sin_family= hp->h_addrtype;
	sa.sin_port= htons((u_short)portnum);

	if ((s= socket(hp->h_addrtype,SOCK_STREAM,0)) < 0){
	   /* get socket */
		ERROR0("call to socket failed");
		return(-1);
	}
	if (connect(s,(struct sockaddr *)&sa,sizeof(sa)) < 0) {       /* connect */
		shutdown(s, 2);
		ERROR0("call to connect failed");
		return(-1);
	}

	/* undo the alarm */
	alarm(0);

	setsockopt(s, SOL_SOCKET, SO_REUSEADDR, (void *)&on, sizeof(on));
#ifdef DEBUG
	printf("Successfully connected.\n");
#endif
	return(s);
}


/*----------------------------------------------------------------------*/
int getline(char *buf, int maxsize, int s){
	int numbytes=0,local_rc=0;;


	/* leave space for the null */
	maxsize--;

	/* assume no lines greater than buf */
	while(1){
/* The following statement is commented to and replaced with code which 
	checks for the time out before reading the socket ; 10/21/99; VG */
/*		if(read(s, &buf[numbytes], 1)<1) break; */
		local_rc = wait_for_select(s);
		if(local_rc < 1)
			break;
		else
			read(s,&buf[numbytes],1);
		numbytes++;
		if((buf[numbytes-1]=='\n') ||
			(numbytes==maxsize)){
			buf[numbytes]='\0';
			return numbytes;
		}
	}
	buf[numbytes]='\0';
	return numbytes;
}
/*----------------Code for base64 encoding of string----------------------*/
void
encode_base64(const char *src, char *dest, int length)
{
  /* Conversion Table for base64 encoding b64map.  */
  static char b64map[64] = {
    'A','B','C','D','E','F','G','H',
    'I','J','K','L','M','N','O','P',
    'Q','R','S','T','U','V','W','X',
    'Y','Z','a','b','c','d','e','f',
    'g','h','i','j','k','l','m','n',
    'o','p','q','r','s','t','u','v',
    'w','x','y','z','0','1','2','3',
    '4','5','6','7','8','9','+','/'
  };
  int i;
  unsigned char *result = (unsigned char *)dest;

  /* Transform the 3x8 bits to 4x6 bits, as required by base64.  */
  for (i = 0; i < length; i += 3) {
      *result++ = b64map[src[0] >> 2];
      *result++ = b64map[((src[0] & 3) << 4) + (src[1] >> 4)];
      *result++ = b64map[((src[1] & 0xf) << 2) + (src[2] >> 6)];
      *result++ = b64map[src[2] & 0x3f];
      src += 3;
  }

  /* Pad the result if necessary...  */
  if (i == length + 1)
    *(result - 1) = '=';
  else if (i == length + 2)
    *(result - 1) = *(result - 2) = '=';
  /* zero-terminate result */
  *result = '\0';
}

/*----------------Encode the username and password into base64 scheme---*/

char *
basic_auth_encode (char *user, char *passwd)
{
  char *t1, *t2, *res;
  int len1 = strlen (user) + 1 + strlen (passwd);
  int len2 = BASE64_LENGTH (len1);

  t1 = (char *) malloc (len1 + 1);
  sprintf (t1, "%s:%s", user, passwd);
  t2 = (char *) malloc (1 + len2);
  encode_base64 (t1, t2, len1);
  res = (char *) malloc (len2 + 8);
  sprintf (res, "Basic %s\r\n", t2);

  return res;
}

	
/*----------------------------------------------------------------------*/
int get_http(int sock, char * host, char *path, FILE *outfile){
	int rc;
	int code,i=0;
	float version;
	/* NOTE: if you change any array sizes, change them in the scanfs, etc. */
	char buf[1024];
	char tmpbuf[32];
	char location[128];
        char *encode; /* contains the base64 encoded scheme */
	char c;
	int headlines,filesize;

	/* write the request to the socket */
	/* if no path specified, make it / */
  	sprintf(buf, "GET %s HTTP/1.0\r\n"
                 "Host: %s\r\n"
                 "User-Agent: %s\r\n"
				"Accept: text/*\r\n\r\n", path[0] ? path : "/", host, appname, useraddr);

        /* Code inserted on 11/18/1999 to support basic authentication scheme -VG */
	if((username != NULL) && (password != NULL)){

		while(buf[i] != '\0')
        	i++;
        buf[i-2] = buf[i-1] = '\0';
        encode = basic_auth_encode(username,password);
        strncat(buf,"Authorization: ",15);
        strncat(buf,encode,strlen(encode));
        strncat(buf,"\r\n\0",3);
    }
		/* Code inserted on 30/3/2000 to introduce if-modified-since field -VG */
	if(httpdate != NULL){
		i = 0;
		while(buf[i] != '\0')
			i++;
        buf[i-2] = buf[i-1] = '\0';
		strncat(buf,"If-Modified-Since: ",19);
		strncat(buf,httpdate,strlen(httpdate));
		strncat(buf,"\r\n\r\n",4);
	}
	
/*	printf("Buffer is \n %s\n",buf); */

	rc = write(sock, buf, strlen(buf));

#ifdef DEBUG
	printf("waiting for reply...\n");
#endif
	

	/* set up the select stuff */
	/* clear the read set */
	FD_ZERO(&readset);
	FD_SET(sock,&readset);
	/* set the timeout */
	timeout.tv_sec = inter_time;
	timeout.tv_usec = 0;

#ifndef RAWGET
	/* first, get the header */
	getline(buf, sizeof(buf), sock);

	/* get the protocol and the code */
	sscanf(buf, "%4s/%4f %3d", tmpbuf, &version, &code);

#ifdef DEBUG
	printf("Got header... HTTP: %s, version: %f, code: %d\n",
		tmpbuf, version, code);
#endif

	/* check the header */
	if(strcmp(tmpbuf, "HTTP") ||
		version <= 0.0 ||
		code < 200 ||
		code > 503){
		/* error with the header */
		ERROR0("Error with the header.  Aborting.\n");
	}

	/* check the code */
	switch(code){
		case 304:		ERROR0("Unmodified");
		case 400:       ERROR0("Bad request");
		case 401:       ERROR0("Unauthorized");
		case 403:       ERROR0("Forbidden");
		case 404:       ERROR0("Not Found");
		case 500:       ERROR0("Internal Server Error");
		case 501:       ERROR0("Not Implemented");
		case 502:       ERROR0("Bad Gateway");
		case 503:       ERROR0("Service Unavailable");
	}


	/* skip lines until we get an empty one */
	location[0]='\0';
	headlines = 0;
	while( (getline(buf, sizeof(buf), sock) > 0) && (headlines < MAX_HEADER_LINES) ){
#ifdef DEBUG
		printf("Header line: %s", buf);
#endif

		if (printheaders) {
			printf("%s", buf);
		}

		if(! printheaders && ((strncmp(buf,"Last-Modified",13)==0) || (strncmp(buf,"Last-modified",13)==0))){
			printf("%s",buf);
		}
		sscanf(buf, "%31s", tmpbuf);
		if(strlen(tmpbuf)==0) break;
		if(strcmp(tmpbuf, "Location:")==0){
			sscanf(buf, "%31s %127s", tmpbuf, location);
			tmpbuf[0]='\0';
			break;
		}
		tmpbuf[0]='\0';
		headlines++;
	}
	if (headlines >= MAX_HEADER_LINES) {
		ERROR0("Too many header lines, something is wrong");
	}

	/* check for redirect */
	if(code==301 || code==302){
		printf("Redirect: %s\n", location);
		/* close the current socket and fd, and call for a new location */
		shutdown(sock, 2);
		/* for recursion, do:
		return get_url(location, outfile);
		*/
		/* I will just exit, since I need to return the address */
		exit(0);
	}
#endif
/* END OF RAWGET IFDEF */

	/* get the body */
	wait_for_select(sock);
	filesize=0;
	while((rc = read(sock, buf, sizeof(buf))) && (filesize < MAX_FILE_SIZEK) ){
		fwrite(buf, rc, 1, outfile);
		wait_for_select(sock);
		filesize++;	/* sizeof(buf) = 1K; is rough limit anyway */
	}

	/* close the socket */
	shutdown(sock, 2);

	return 1;
}

/*----------------------------------------------------------------------*/
int parse_url(char *url, char **serverstrp, int *portp, char **pathstrp){
	char buf[256];
	int serverlen, numread=0;

	/* go through the url */
	/* reset url to point PAST the http:// */
	/* assume it's always 7 chars! */
	url = url+7;

	/* no http:// now... server is simply up to the next / or : */
	sscanf(url, "%255[^/:]", buf);
	serverlen = strlen(buf);
	*serverstrp = (char *)malloc(serverlen+1);
	strcpy(*serverstrp, buf);

	if(url[serverlen]==':'){
		/* get the port */
		sscanf(&url[serverlen+1], "%d%n", portp, &numread);
		/* add one to go PAST it */
		numread++;
	}else{
		*portp = 80;
	}

	/* the path is a pointer into the rest of url */
	*pathstrp = &url[serverlen+numread];

	return 0;
}

/*----------------------------------------------------------------------*/
int get_url(char *url, FILE *outfile){
	char *server;
	int port;
	char *path;
	char *host;
	int rc, s, hostlen;

	rc = parse_url(url, &server, &port, &path);
	if(rc<0){
		ERROR1("Problem with parsing url %s", url);
	}

#ifdef DEBUG
	printf("http connection to %s:%d, path: %s\n", server, port, path);
#endif

	s = call_socket(server, port);
	if(s==-1){
		/* error msgs in call_socket */
		return -1;
	}

 	hostlen = strlen(server) + 6;
 	host = (char *)malloc(hostlen+1);
 	snprintf(host,hostlen,"%s:%d",server,port);
        rc = get_http(s, host, path, outfile);
	free(host);
 
 	/* we can free memory for server string */
  	free(server);
 	return rc;
}

/*----------------------------------------------------------------------*/
int main(int argc, char *argv[]){
	int rc;
	FILE *outfile;
	int index;
	char *outfilename=NULL;

	if(argc<2){
		ERROR1("Format: %s <http://server[:port]/path> [-o <outputfile>] [-u userid@server.location] [-n username] [-p password] [-t max_time] [-i inter_time] [-d httpdate] [-h]", argv[0]);
	}

	/* parse args */
	for(index=1; index<argc; index++){
		if(strncmp(argv[index], "-t", 2)==0){
			max_time = atoi(argv[++index]);
		}
		else if(strncmp(argv[index], "-i", 2)==0){
			inter_time = atoi(argv[++index]);
		}
		else if(strncmp(argv[index], "-u", 2)==0){
			useraddr = argv[++index];
		}
		else if(strncmp(argv[index], "-o", 2)==0){
			outfilename = argv[++index];
		}
        	else if(strncmp(argv[index], "-n", 2)==0){
        	    	username = argv[++index];
        	}
        	else if(strncmp(argv[index], "-p", 2)==0){
            		password = argv[++index];
        	}
		else if(strncmp(argv[index], "-d", 2)==0){
            		httpdate = argv[++index];
        	} 
		else if (strncmp(argv[index], "-h", 2)==0) {
	    		printheaders = 1;
		}
	} /* for argc*/
	if(httpdate != NULL)
		if((rc = check_date(httpdate)) < 0) {
			printf("Invalid date format\n Please follow this example : \"Sat, 09 Aug 2000 18:34:46 GMT\"\n");
			exit(1);
		}

	/* install the handler */
	signal(SIGALRM, alarm_handler);
	alarm(max_time);
	/* ### TO DO -- make it work okay with recursion */

	/* open the file */
	if(outfilename==NULL){
		outfile = stdout;
	}else{
		outfile = fopen(outfilename, "w");
		if(outfile==NULL){
			ERROR1("Cannot open outfile %s", argv[2]);
		}
	}

	rc = get_url(argv[1], outfile);

	if(rc<0){
		ERROR0("Cannot get page.");
	}
}
int check_date(const char d[]){

char days[7][3] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
char fulldays[7][9] = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday" , "Saturday"};
char months[12][3] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct" , "Nov", "Dec"};

    int i,j,k;
    char td[10];

	if(strlen(d) != 29){
		printf("Invalid format : Length of the httpdate should be 29 characters\n");
		return(-1);
	}

    for(i=0; i<7; i++){
        if(strncmp(d,days[i],3) == 0)
            break;
    }
    if(i == 7){
        printf("Invalid day\n");
        return(-1);
    }              /* check for months */
    memcpy(td,d+8,3);
    td[3]='\0';
    for(i=0; i<12; i++){
        if(strncmp(td,months[i],3) == 0)
            break;
    }
    if(i == 12){
        printf("Invalid month\n");
        return(-1);
    }
    if((d[3] != ',') || (d[4] != ' ') || (d[7] != ' ') || (d[11] != ' ') || (d[16] != ' ') || (d[25] != ' ') || (d[22] != ':') || (d[19] != ':')){
        printf("Invalid date format\n");
        return(-1);
    }
    memcpy(td,d+5,2);
    td[2]='\0';
    i = atoi(td);

    if((i<1) || (i>31)){
        printf("Invalid date number\n");
        return(-1);
    }
    for(i=12; i<16; i++){
        if((d[i] < '0') || (d[i] > '9')){
            printf("Invalid character in the year\n");
        }
    }

    for(i=17,j=1; i<24; i+=3,j++){
        memcpy(td,d+i,2);
        td[2]='\0';
        k = atoi(td);
        if(j==1)
            if((k < 0) || (k>23)){
                printf("Invalid number of hours\n");
                return(-1);
            }
        else
            if((k < 0) || (k>59)){
                printf("Invalid number of hours\n");
                return(-1);
            }
    }
    memcpy(td,d+26,3);
    td[3]='\0';
    if(strcmp(td,"GMT") != 0){
        printf("Invalid standard\n");
        return(-1);
    }
	return(1);
}

