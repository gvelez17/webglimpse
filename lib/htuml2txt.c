/*  	Program Written to Untag a HTML file : Maqsood Mohammed (25 Jan 2000) */
/*      This is a .c version of htuml2txt.pl file to be incorporated in glimpse */

#include <stdio.h>
#include <string.h>
#include <ctype.h>

char lineToSearch[100];
void fixSpecial(void);
static char* string[]= {"b","/b","i","/i","em","/em","font","/font","strong","/strong","big","/bi
g","sup","/sup","sub","/sub","u","/u","strike","/strike","style","/style"};
static char* STRING[]= {"B","/B","I","/I","EM","/EM","FONT","/FONT","STRONG","/STRONG","BIG","/BI
G","SUP","/SUP","SUB","/SUB","U","/U","STRIKE","/STRIKE","STYLE","/STYLE"};
int check(char *arr);

main()
{
        int c,k,tagLen,tagread;
        char *getLine,*tempstr,*isitspecial;
        FILE *tempfp;
        getLine=(char*)malloc(100);
        tempstr=(char*)malloc(100);
        isitspecial=(char*)malloc(100);
        tempfp=fopen("temp.html","w+");
           /*create a temporary file to store results of untaging input file */

        while(1)
        {
            k=0;tagread=0;tagLen=0;
            c=getc(stdin);
            if (c==EOF) break;
            if (c != '<')
                      putc(c,tempfp);
            else
                while (c != '>') {
                   c=getc(stdin);
                   if (!isspace(c) && (c!='>'))
                   {
                   tagLen++;  if (!tagread) tempstr[k++]=c;
                    }
                   else if (isspace(c))/* we are concerned only with tag entity ,not the whole tag*/
                    {
                      tagLen++; tempstr[k]='\0';
                      tagread=1;strcpy(isitspecial,tempstr);
                    }
                   else if (c == '>') /* end of tag reached*/
                    {
                      tempstr[k]='\0';tagread=1;
                     strcpy(isitspecial,tempstr);
                    }
                   if (c==EOF) break;
                }
             if (!check(isitspecial)&&(tagLen!=0)) /* check if the tag is a special tag,if not put a space */
               putc(' ',tempfp);
        }

        fseek(tempfp,0,SEEK_SET); /* go to start of temporary file */
        while ((fgets(getLine,80,tempfp))!=NULL)
        {
              strcpy(lineToSearch,getLine);
              fixSpecial(); /* fix those special characters by reading from temporary file,which contains the untagged ones */
              strcpy(getLine,lineToSearch);
              fputs(getLine,stdout); /* write the modified line into output file */
        }
        fclose(tempfp);
        remove("temp.html"); /* remove the temporary file */
}

int check(char *array)
{
       int i,flag=0;
       for (i=0;i<22;i++) /* comparision if array is a special tag */
       if(strcmp(array,string[i])==0)
            flag=1;
       toupper(array);
       for (i=0;i<22;i++)
       if(strcmp(array,STRING[i])==0)/* upper case comparision */
            flag=1;
       if (flag) return 1; /* if special tag,return 1 else return 0*/
       else return 0;
}

SearchReplace(char inputString[100],char searchPattern[50],char replacePattern[50])
{

     int i,j,k,patternStartsAt,t,ii,patternFound=0,remLen;
     char tempinputString[100];
     for (i=0;i<strlen(inputString);i++)    /* SEARCH */
     {
           k=0;ii=i;
           for (j=0;j<strlen(searchPattern);ii++,j++)
            if (inputString[ii]==searchPattern[j])
                    k++;
           if (k==strlen(searchPattern)) {
                patternFound=1;
                patternStartsAt=i;
           }
     }
     strcpy(tempinputString,inputString);
     remLen=strlen(tempinputString)-patternStartsAt-strlen(searchPattern);
     if (patternFound)                        /* REPLACE */
     {
          for (i=0;i<strlen(replacePattern);i++)
                  tempinputString[patternStartsAt+i]=replacePattern[i];
          for (k=0;k<remLen;k++)
                  tempinputString[patternStartsAt+i+k]=inputString[patternStartsAt+strlen(searchPattern)+k];
          tempinputString[patternStartsAt+i+k]='\0';
          strcpy(lineToSearch,tempinputString); /* lineToSearch is modified to contain the 'new replaced' line */
     }
}




void fixSpecial(){
       char a,replace[50];


a=' ';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#160;",replace);
       SearchReplace(lineToSearch,"&nbsp;",replace);

a='¡';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#161;",replace);
       SearchReplace(lineToSearch,"&iexcl;",replace);

a='¢';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#162;",replace);
       SearchReplace(lineToSearch,"&cent;",replace);

a='£';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#163;",replace);
       SearchReplace(lineToSearch,"&pound;",replace);

a='¤';replace[0]=a;replace[1]='\0';
         SearchReplace(lineToSearch,"&#164;",replace);
       SearchReplace(lineToSearch,"&curren;",replace);

a='¥';replace[0]=a;replace[1]='\0';
SearchReplace(lineToSearch,"&#165;",replace);
       SearchReplace(lineToSearch,"&yen;",replace);
     
a='¦';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#166;",replace);
       SearchReplace(lineToSearch,"&brvbar;",replace);

a='§';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#167;",replace);
       SearchReplace(lineToSearch,"&sect;",replace);

a='¨';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#168;",replace);
       SearchReplace(lineToSearch,"&uml;",replace);

a='©';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#169;",replace);
       SearchReplace(lineToSearch,"&copy;",replace);

a='ª';replace[0]=a;replace[1]='\0';
SearchReplace(lineToSearch,"&#170;",replace);
       SearchReplace(lineToSearch,"&ordf;",replace);


a='«';replace[0]=a;replace[1]='\0';
     SearchReplace(lineToSearch,"&#171;",replace);
       SearchReplace(lineToSearch,"&laquo;",replace);
  
a='¬';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#172;",replace);
       SearchReplace(lineToSearch,"&not;",replace);

a='\\';replace[0]=a;replace[1]='\0';
    SearchReplace(lineToSearch,"&#173;",replace);
       SearchReplace(lineToSearch,"&shy;",replace);
   
a='®';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#174;",replace);
       SearchReplace(lineToSearch,"&reg;",replace);
     
a='¯';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#175;",replace);
       SearchReplace(lineToSearch,"&macr;",replace);
     

a='°';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#176;",replace);
       SearchReplace(lineToSearch,"&deg;",replace);
     

a='±';replace[0]=a;replace[1]='\0';
     SearchReplace(lineToSearch,"&#177;",replace);
       SearchReplace(lineToSearch,"&plusmn;",replace);
     

a='²';replace[0]=a;replace[1]='\0';
SearchReplace(lineToSearch,"&#178;",replace);
       SearchReplace(lineToSearch,"&sup2;",replace);
     


a='³';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#179;",replace);
       SearchReplace(lineToSearch,"&sup3;",replace);
    

a='´';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#180;",replace);
       SearchReplace(lineToSearch,"&acute;",replace);
      

a='µ';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#181;",replace);
       SearchReplace(lineToSearch,"&micro;",replace);

a='¶';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#182;",replace);
       SearchReplace(lineToSearch,"&para;",replace);
     

a='·';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#183;",replace);
       SearchReplace(lineToSearch,"&middot;",replace);
     

a='¸';replace[0]=a;replace[1]='\0';
    SearchReplace(lineToSearch,"&#184;",replace);
       SearchReplace(lineToSearch,"&cedil;",replace);
   
a='¹';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#185;",replace);
       SearchReplace(lineToSearch,"&sup1;",replace);
     

a='º';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#186;",replace);
       SearchReplace(lineToSearch,"&ordm;",replace);
     
a='»';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#187;",replace);
       SearchReplace(lineToSearch,"&raquo;",replace);
     

a='¼';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#188;",replace);
       SearchReplace(lineToSearch,"&frac14;",replace);
    

a='½';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#189;",replace);
       SearchReplace(lineToSearch,"&frac12;",replace);
     

a='¾';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#190;",replace);
       SearchReplace(lineToSearch,"&frac34;",replace);
   

a='¿';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#191;",replace);
       SearchReplace(lineToSearch,"&iquest;",replace);
     

a='À';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#192;",replace);
       SearchReplace(lineToSearch,"&Agrave;",replace);
     
a='Á';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#193;",replace);
       SearchReplace(lineToSearch,"&Aacute;",replace);
    

a='Â';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#194;",replace);
       SearchReplace(lineToSearch,"&circ;",replace);
      

a='Ã';replace[0]=a;replace[1]='\0';
    SearchReplace(lineToSearch,"&#195;",replace);
       SearchReplace(lineToSearch,"&Atilde;",replace);
   

a='Ä';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#196;",replace);
       SearchReplace(lineToSearch,"&Auml;",replace);
    
a='Å';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#197;",replace);
       SearchReplace(lineToSearch,"&ring;",replace);
      

a='Æ';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#198;",replace);
       SearchReplace(lineToSearch,"&AElig;",replace);
    

a='Ç';replace[0]=a;replace[1]='\0';
    SearchReplace(lineToSearch,"&#199;",replace);
       SearchReplace(lineToSearch,"&Ccedil;",replace);
    

a='È';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#200;",replace);
       SearchReplace(lineToSearch,"&Egrave;",replace);
      

a='É';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#201;",replace);
       SearchReplace(lineToSearch,"&Eacute;",replace);
     

a='Ê';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#202;",replace);
       SearchReplace(lineToSearch,"&Ecirc;",replace);
     

a='Ë';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#203;",replace);
       SearchReplace(lineToSearch,"&Euml;",replace);
     

a='Ì';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#204;",replace);
       SearchReplace(lineToSearch,"&Igrave;",replace);
     

a='Í';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#205;",replace);
       SearchReplace(lineToSearch,"&Iacute;",replace);
    

a='Î';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#206;",replace);
       SearchReplace(lineToSearch,"&Icirc;",replace);
     

a='Ï';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#207;",replace);
       SearchReplace(lineToSearch,"&Iuml;",replace);
     

a='Ð';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#208;",replace);
       SearchReplace(lineToSearch,"&ETH;",replace);
      

a='Ñ';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#209;",replace);
       SearchReplace(lineToSearch,"&Ntilde;",replace);
    

a='Ò';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#210;",replace);
       SearchReplace(lineToSearch,"&Ograve;",replace);
     

a='Ó';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#211;",replace);
       SearchReplace(lineToSearch,"&Oacute;",replace);
     

a='Ô';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#212;",replace);
       SearchReplace(lineToSearch,"&Ocirc;",replace);
     

a='Õ';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#213;",replace);
       SearchReplace(lineToSearch,"&Otilde;",replace);
     

a='Ö';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#214;",replace);
       SearchReplace(lineToSearch,"&Ouml;",replace);

a='×';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#215;",replace);
       SearchReplace(lineToSearch,"&times;",replace);
     

a='Ø';replace[0]=a;replace[1]='\0';
    SearchReplace(lineToSearch,"&#216;",replace);
       SearchReplace(lineToSearch,"&Oslash;",replace);
    

a='Ù';replace[0]=a;replace[1]='\0';
SearchReplace(lineToSearch,"&#217;",replace);
       SearchReplace(lineToSearch,"&Ugrave;",replace);
      

a='Ú';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#218;",replace);
       SearchReplace(lineToSearch,"&Uacute;",replace);
    

a='Û';replace[0]=a;replace[1]='\0';
    SearchReplace(lineToSearch,"&#219;",replace);
       SearchReplace(lineToSearch,"&Ucirc;",replace);
   

a='Ü';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#220;",replace);
       SearchReplace(lineToSearch,"&Uuml;",replace);
     

a='Ý';replace[0]=a;replace[1]='\0';
     SearchReplace(lineToSearch,"&#221;",replace);
       SearchReplace(lineToSearch,"&Yacute;",replace);
   

a='Þ';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#222;",replace);
       SearchReplace(lineToSearch,"&THORN;",replace);
      

a='ß';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#223;",replace);
       SearchReplace(lineToSearch,"&szlig;",replace);
      

a='à';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#224;",replace);
       SearchReplace(lineToSearch,"&agrave;",replace);
     

a='á';replace[0]=a;replace[1]='\0';
      SearchReplace(lineToSearch,"&#225;",replace);
       SearchReplace(lineToSearch,"&aacute;",replace);
 

a='â';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#226;",replace);
       SearchReplace(lineToSearch,"&acirc;",replace);
     

a='ã';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#227;",replace);
       SearchReplace(lineToSearch,"&atilde;",replace);
    

a='ä';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#228;",replace);
       SearchReplace(lineToSearch,"&auml;",replace);
     

a='å';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#229;",replace);
       SearchReplace(lineToSearch,"&aring;",replace);
     

a='æ';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#230;",replace);
       SearchReplace(lineToSearch,"&aelig;",replace);
    

a='ç';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#231;",replace);
       SearchReplace(lineToSearch,"&ccedil;",replace);
    

a='è';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#232;",replace);
       SearchReplace(lineToSearch,"&egrave;",replace);
    

a='é';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#233;",replace);
       SearchReplace(lineToSearch,"&eacute;",replace);
    

a='ê';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#234;",replace);
       SearchReplace(lineToSearch,"&ecirc;",replace);
     

a='ë';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#235;",replace);
       SearchReplace(lineToSearch,"&euml;",replace);
     

a='ì';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#236;",replace);
       SearchReplace(lineToSearch,"&igrave;",replace);
     

a='í';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#237;",replace);
       SearchReplace(lineToSearch,"&iacute;",replace);
     

a='î';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#238;",replace);
       SearchReplace(lineToSearch,"&icirc;",replace);
    

a='ï';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#239;",replace);
       SearchReplace(lineToSearch,"&iuml;",replace);
    

a='ð';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#240;",replace);
       SearchReplace(lineToSearch,"&ieth;",replace);
    

a='ñ';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#241;",replace);
       SearchReplace(lineToSearch,"&ntilde;",replace);
     

a='ò';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#242;",replace);
       SearchReplace(lineToSearch,"&ograve;",replace);
    

a='ó';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#243;",replace);
       SearchReplace(lineToSearch,"&oacute;",replace);
      

a='ô';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#244;",replace);
       SearchReplace(lineToSearch,"&ocirc;",replace);
   

a='õ';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#245;",replace);
       SearchReplace(lineToSearch,"&otilde;",replace);
     

a='ö';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#246;",replace);
       SearchReplace(lineToSearch,"&ouml;",replace);
    

a='÷';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#247;",replace);
       SearchReplace(lineToSearch,"&divide;",replace);
      

a='ø';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#248;",replace);
       SearchReplace(lineToSearch,"&oslash;",replace);
      

a='ù';replace[0]=a;replace[1]='\0';
    SearchReplace(lineToSearch,"&#249;",replace);
       SearchReplace(lineToSearch,"&ugrave;",replace);
   

a='ú';replace[0]=a;replace[1]='\0';
 SearchReplace(lineToSearch,"&#250;",replace);
       SearchReplace(lineToSearch,"&uacute;",replace);
    

a='û';replace[0]=a;replace[1]='\0';
    SearchReplace(lineToSearch,"&#251;",replace);
       SearchReplace(lineToSearch,"&ucirc;",replace);
   

a='ü';replace[0]=a;replace[1]='\0';
  SearchReplace(lineToSearch,"&#252;",replace);
       SearchReplace(lineToSearch,"&uuml;",replace);
     

a='ý';replace[0]=a;replace[1]='\0';
   SearchReplace(lineToSearch,"&#253;",replace);
       SearchReplace(lineToSearch,"&yacute;",replace);

a='þ';replace[0]=a;replace[1]='\0';
       SearchReplace(lineToSearch,"&#254;",replace);
       SearchReplace(lineToSearch,"&thorn;",replace);

a='ÿ';replace[0]=a;replace[1]='\0';
       SearchReplace(lineToSearch,"&#255;",replace);
       SearchReplace(lineToSearch,"&yuaml;",replace);

a='"';replace[0]=a;replace[1]='\0';
       SearchReplace(lineToSearch,"&#34;",replace);
       SearchReplace(lineToSearch,"&quot;",replace);

a='&';replace[0]=a;replace[1]='\0';
       SearchReplace(lineToSearch,"&#38;",replace);
       SearchReplace(lineToSearch,"&amp;",replace); 

}
