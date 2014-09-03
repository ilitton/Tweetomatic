/*************************************************************************************
MACRO: Tweetomatic
 
PARAMETERS:
       Search_Term = Word or phrase you want tweets to contain. Represent hashtags (#)
with %23.
       Target = Number of tweets you want returned.
 
REQUIREMENTS:
       Bearer token from Twitter Developers' Page to authorize requests to Twitter API
(Not provided)
       %GrabTweet (Provided)
 
OUTPUT VARIABLES:
       created_at1 = Date of tweet
       tweet_id = Tweet ID
       text = Tweet
       user_id = User ID
       name = Name of account
       screen_name = Screen Name
       location = Location specified by user
       created_at2 = Date account was created
       lang = Language
       latitude = Latitude coordinate (Only available if user opts-in to use Tweeting  
With Location Feature on)
       longitude = Longitude coordinate (Only available if user opts-in to use
Tweeting With Location Feature on)
       date = date of tweet as SAS date value
 
REQUIRED FILES TO BE CREATED BEFORE RUNNING THE MACRO:
-Batch script (Commands found on Pg2) pointing to a text file containing number of seconds to wait (labeled as waittime.txt on Pg2)
-Text file containing the integer 20 or a larger integer (labeled as waittime.txt in paper)
-Batch script (Same commands found on Pg2) pointing to text file containing average number of seconds to wait (labeled as avgwaittime.txt- does not have to be created before running macro)
-Batch script (Commands found on Pg3) to prompt user whether to download more tweets
 
WARNINGS:
-If original tweets are included, the macro will return more observations than the specified target amount.
-Macro processing must be terminated manually if user wants to stop downloading before the amount of tweets already downloaded is more than specified.
-User should remember to change the pathnames pointing to the location of the data as well as the batch scripts.
-One location can be used for both the data and batch scripts. However, multiple locations can be referenced as well if the user wants to use separate directories for the data and batch code.
-Path within batch files are specific to the type of operating system and must point to where you store the text files (waittime.txt, avgwaittime.txt)
 
GITHUB LOCATION FOR MOST RECENT VERSION OF MACRO: https://github.com/ilitton
 
************************************************************************************/
%MACRO Tweetomatic(search_term, target);
%LET oldloopcount = ;
%LET olderid = NA;
%LET loopvar = N;
 
/*Downloads 100 most recent tweets to create base file*/
%GRABTWEET(&search_term, 100);
 
/*Create a macro variable to count the number of observations*/
PROC SQL NOPRINT;
       SELECT COUNT(*)
       INTO :loopcount
       FROM test;
QUIT;
 
DATA first100;
SET test;
RUN;
 
/*Forces program to wait before next URL call. The path in the CALL SYSTEM command is specific for a Windows computer. Path may need to be changed depending on operating system.*/
OPTIONS NOXWAIT;
DATA _NULL_;
CALL SYSTEM('call C:\Users\Administrator\Documents\batch\wait20.bat');
RUN;
 
/*Downloads as many older tweets as possible than the last tweet downloaded above*/
%DO %UNTIL(&oldloopcount = 0 OR &oldloopcount = 1);
 
/*In order to grab more tweets and return older tweets (Tweets with IDs lower than specified tweet_id), we need to store the id of the oldest tweet downloaded in a macro variable. The stored value of &old_id will be used as the max_id parameter in the GET search/tweets url.*/
              DATA last;
              SET first100 (FIRSTOBS = &loopcount);
              CALL SYMPUT("old_id", tweet_id);
              RUN;
 
              %LET loopvar = NA;
              %LET olderid = Y;
      
              %GRABTWEET(&search_term, 100);
 
              PROC APPEND BASE = first100 DATA = test FORCE;
 
              PROC SQL NOPRINT;
                      SELECT COUNT(*)
                      INTO :oldloopcount
                      FROM test;
              QUIT;
              %LET loopcount = %EVAL(&loopcount+&oldloopcount);
%END;
%LET i = 0;
 
/*In order to grab more tweets and return more recent tweets (Tweets with IDs higher than specified tweet_id), we need to store the id of the most recent tweet in a macro variable. The stored value of &recent_id will be used as the since_id parameter in the GET search/tweets url.*/
DATA first;
       SET first100 (OBS = 1);
       CALL SYMPUT("recent_id", tweet_id);
RUN;
 
/*Downloads as many recent tweets as possible until number of tweets downloaded is more than amount specified by user.*/
%DO %UNTIL(&loopcount > &target);
       %LET i=%EVAL(&i+1);
       %LET olderid = NA;
       %LET loopvar = Y;
 
       %GRABTWEET(&search_term, 100);
 
       PROC APPEND BASE = first100 DATA = test FORCE;
 
       PROC SQL NOPRINT;
              SELECT COUNT(*)
              INTO :recentloopcount
              FROM test;
       QUIT;
/*Calculates the time between observations for the most recently downloaded tweets*/
       DATA main_conversion;
              SET test;
/*temp ~=2  removes original tweets of retweets for calculating the rate of tweets*/
              IF temp ~= 2 THEN time_diff = abs(dif(date));
       RUN;
             
       PROC MEANS DATA = main_conversion MEAN;
              VAR time_diff;
              OUTPUT OUT = test_mean MEAN = avgtime;
       RUN;
 
/*Rounds average rate of tweets because the TIMEOUT batch command only accepts integers. Next, it writes this integer to a text file, which will be used in the batch script. The text file should only contain a single integer representing the amount of time the program will wait before downloading more data*/
       DATA _null_;
              SET test_mean;
              avgrate = CEIL(avgtime);
              IF avgrate > 99999 THEN avgrate = 99999;
              FILE 'C:\Users\Administrator\Documents\batch\avgwaittime.txt';
              PUT avgrate;
RUN;
/*Executes batch processing that forces the program to wait the calculated amount of time. The path in the CALL SYSTEM command is specific for a Windows computer. Path may need to be changed depending on operating system.*/
       OPTIONS NOXWAIT;
       DATA _NULL_;
       CALL SYSTEM('call C:\Users\Administrator\Documents\batch\batch_run.bat');
       RUN;
 
       %LET loopcount = %EVAL(&loopcount+&recentloopcount);
 
       PROC SORT DATA = first100 NODUPKEY;
              BY DESCENDING tweet_id;
       RUN;
 
       PROC SQL NOPRINT;
              SELECT COUNT(*)
              INTO :loopcount
              FROM first100;
       QUIT;
 
/*Sometimes older tweets have a larger tweet_id of length 17. Due to the PROC SORT, these tweets are at the top of the data set and will be incorrectly used as the id for the since_id URL parameter. A subsetting IF checking whether the length of the tweet is exactly 18 avoids the problem of downloading recent tweets based on an older date.*/
 
       DATA testing;
              SET first100;
              lengthid = length(tweet_id);
              IF lengthid = 18;
       RUN;
 
/*Sets id of most recent tweet into a macro variable to be used for the since_id URL parameter*/
       PROC SQL NOPRINT;
              SELECT MAX(tweet_id)
              INTO :recent_id
              FROM testing;
       QUIT;
 
/*Executes batch processing that prompts the user whether or not to download more data if there are more than 10 iterations and if the number of tweets most recently downloaded are less than 5. If the user types "Y", the program will continue until the number of observations downloaded is more than the target specified. If the user types "N", batch script creates a file to be used in a condition to terminate current processing of the macro.If the user does not respond within 10 seconds, the default response is "Y". The path in the CALL SYSTEM command is specific for a Windows computer. Path may need to be changed depending on operating system.
*/
%IF (&i > 10 AND &recentloopcount < 5) %THEN %DO;
OPTIONS NOXWAIT;
DATA _NULL_;
CALL SYSTEM('call C:\Users\Administrator\Documents\batch\prompt.bat');
RUN;
%END;
 
/*This code will execute if the user types "N" in the prompt from the batch script. It will create a fileref for the file written by batch and checks for the file's existence. If the file exists, it will delete the fileref and terminate current macro processing toreturn downloaded tweets. */
 
%LET filrf = exitfile;
%LET rc = %SYSFUNC(FILENAME(filrf, C:\Users\Administrator\Documents\batch\exittest.txt));
%IF %SYSFUNC(FEXIST(&filrf)) %THEN %DO;
       %SYSFUNC(FDELETE(&filrf));
       %LET rc = %SYSFUNC(FILENAME(&filrf));
       %RETURN;
%END;
%END;
%MEND;
 
%MACRO grabtweet(search_term, target_amount);
/*Specifies the input token file for authorization to access API 1.1*/
filename auth "C:\Users\Administrator\Documents\token.txt";
 
/*Specifies the output JSON file that will contain the tweets*/
filename twtOut "C:\Users\Administrator\Documents\data\Test.txt";
 
/*Sets the following parameters to use in the GET search/tweets url:
       COUNT = number of tweets to grab
       RESULT_TYPE= what type of search tweets to grab. Options include the following:
              --> Popular = returns only the most popular tweets with regard to search
term
              --> Recent = returns only the most recent tweets with regard to search
term
              --> Mixed = popular and real time tweets
       SINCE_ID = returns tweets more recent than specified tweet
       MAX_ID = returns tweets older than specified tweet
*/
 
%IF &target_amount < 100 %THEN %LET num_tweet = %NRSTR(&count=)&target_amount;
%ELSE %LET num_tweet = %NRSTR(&count=100);
%LET type = %NRSTR(&result_type=recent);
%LET recent_tweet = %NRSTR(&since_id=)&recent_id;
%LET id = %NRSTR(&max_id=)&old_id;
 
/*Issues GET search/tweet URL to download the most recent 100 tweets for a search term specified by the user*/
%IF &loopvar = N %THEN %DO;
PROC HTTP
HEADERIN = auth
METHOD = "get"
URL = "https://api.twitter.com/1.1/search/tweets.json?q=&search_term&type&num_tweet"
OUT = twtOut;
RUN;
%END;
 
/*Issues GET search/tweet URL to download 100 tweets more recent than the tweet id specified by since_id parameter*/
%IF &loopvar = Y %THEN %DO;
PROC HTTP
HEADERIN = auth
METHOD = "get"
URL = "https://api.twitter.com/1.1/search/tweets.json?q=&search_term&recent_tweet&type&num_tweet"
OUT = twtOut;
RUN;
%END;
 
/*Issues GET search/tweet URL to download 100 tweets older than the tweet id specified by max_id parameter*/
%IF &olderid = Y %THEN %DO;
PROC HTTP
HEADERIN = auth
METHOD = "get"
URL = "https://api.twitter.com/1.1/search/tweets.json?q=&search_term&id&type&num_tweet"
OUT = twtOut;
RUN;
%END;
 
DATA test (DROP= text_start text_end userid_end name_end retweeted original_tweet latitude_c longitude_c);
INFILE "C:\Users\Administrator\Documents\data\test.txt" LRECL = 1000000 TRUNCOVER SCANOVER dlm=',' dsd;
informat created_at1 $30. tweet_id $18. text $140. user_id $15. name $185. screen_name $185. location $185. created_at2 $30.
        lang $2. retweeted $18. latitude_c $25. longitude_c $25. latitude 11.8 longitude 11.8;
INPUT @'"created_at":' created_at1
     @'"id":' tweet_id
     @'"text":' text 
     @'"user":{"id":' user_id
     @'"name":' name
     @'"screen_name":' screen_name
     @'"location":' location
     @'"created_at":' created_at2 
     @'"lang":' lang
     @'"coordinates":' latitude_c @;
              IF latitude_c = 'null' THEN INPUT  @'butors":null,' retweeted @@;
              ELSE INPUT longitude_c @'butors":null,' retweeted @@;
 
IF latitude_c = 'null' THEN latitude_c = .;
ELSE latitude_c = SUBSTR(latitude_c, 2, 11);
latitude = INPUT(latitude_c, 11.8);
IF longitude_c = '' THEN longitude_c = .;
ELSE longitude_c = SUBSTR(longitude_c, 1, 11);
IF FIND(longitude_c, ']') ~= 0 THEN longitude_c = SUBSTR(longitude_c, 1, INDEX(longitude_c, ']')-1);
IF FIND(longitude_c, '}') ~= 0 THEN longitude_c = SUBSTR(longitude_c, 1, INDEX(longitude_c, '}')-1);
longitude = INPUT(longitude_c, 11.8);
text_start = INDEX(text, '"')+1;
text_end = INDEX(text,'","');
IF text_end ~= 0 THEN text = SUBSTR(text,text_start,text_end-1);
IF text_end = 0 THEN text = SUBSTR(text, text_start);
userid_end = INDEX(user_id, ',"');
IF userid_end ~= 0 THEN user_id = SUBSTR(user_id,1,userid_end-1);
name_end = INDEX(name, '","s');
IF name_end = 1 THEN DO;
name_end = 2;
       name = 'NA';
END;
IF name_end ~IN(0,1) THEN name = SUBSTR(name, 1, abs(name_end-1));
 
/*The macro is suppose to return only the most recent tweets, but the file contains the original tweets of retweets, so we must distinguish between original tweets and retweets using the variable Original_tweet. Retweets will have the
string "retweeted_status" as a member while non-tweets will have a different string.Since original_tweet will be a nonzero integer for retweets instead of the original tweets, the variable must be lagged so that "retweeted_status" will be part of the observation representing original tweets. Now that original_tweet is a nonzero integer for original tweets, these observations can be flagged, and regular tweets(whose value of temp will be zero) can be used in the CALL SYMPUT function to grab the tweet_id for the max_id URL parameter.*/
       original_tweet = FIND(retweeted, "retweeted_status");
       temp = LAG(original_tweet);
 
/*Converts date of tweet to SAS date*/
date = input(cat(substr(created_at1, 9, 2), substr(created_at1, 5, 3), substr(created_at1, 29, 2), ':', substr(created_at1, 12, 8)), DATETIME16.);
RUN;
 
%MEND;
 
 
