Tweet-o-matic: An Automated Approach to Batch Pro
===============
A SAS macro to download tweets without manual intervention. 

### Requirements

#### Not Provided:
* Bearer token from Twitter Developers' Page to authorize requests to Twitter API - Not provided
* Text file containing the integer 20 or a larger integer (labeled as waittime.txt in Tweetomatic.pdf) - Not Provided 

#### Provided:
* %GrabTweet macro
* waittime.bat: Batch script pointing to a text file containing number of seconds to wait (labeled as waittime.txt - Found on Pg2 of Tweetomatic.pdf)
* batch\_run.bat: Batchscript pointing to text file containing average number of seconds to wait (labeled as avgwaittime.txt- does not have to be created before running macro)
* prompt.bat: Batch script to prompt user whether to download more tweets

###Example macro call: 
    %Tweetomatic(%23Marvel, 1000);