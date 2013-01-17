#!/usr/bin/perl
use Mail::Sendmail;
use MIME::Lite;
use Mail::Internet;

my %data;
my %dupdata;
my %alldata; #Stores all the address information
my $lname; 
my $badcount = 0;
my $goodcount = 0;

my $addresslabels = '"date","name","address","city","state","zip"'."\n";
my $problems = '"date","name","address","city","state","zip"'."\n";

#Enter which email the csv file should be sent to.
my $mailto = 'somebody@emailsomeone.blarg';


$message = new Mail::Internet(STDIN);
$header = $message->head();
#print join("\n",sort $header->tags);


#Grab the body as an array and join it back together so we can split it
# up into records.
$body = $message->body();
$bodystring = join("",@$body);

#We are done with $body
undef $body;
#We are done with the message object
undef $header;
undef $message;

#$/ = ""; #setup paragraph mode, so chomp will remove all trailing newlines.

#Split the body into individual records and grab the sequence number,
# and phone number
#/3:(\d{1,2})\n(\W*...)/ or it could just be 3
#Old Notice Format
#@chunks = split(/(?:\s{5}3:(\d{1,2})|\s{6}3).\s*(\d{3}-\d{3}-\d{4})/sm,$bodystring);

#New Notice Format, Split the messages apart based on the notice and count at the bottom of each notice.
@chunks = split(/^(1|2|10):(\d{1,3})/sm,$bodystring);

#Done with bodystring;
undef $bodystring;
print `date`;
my $thedate = `date +%m-%d-%Y`;
print "Number of chunks is ->".scalar(@chunks)."\n";

my $startline = 0;

#Print out the Sequence number and phone for each notice.
for (my $i = 0; $i < scalar(@chunks) -1; $i += 3){
	print "I is $i\n";
	print "  Sequence is ".$chunks[$i+2]."\n";
	print "  Phone is ".$chunks[$i+2]."\n";
	#grab branch name from notice
	#print $chunks[$i];
	if ($chunks[$i] =~ /^([a-zA-Z ]+) Library/m){ 
		#assign each notice to a branch and add to a data structure
		print "   library is -> $1 \n";
    
    # This allows you to exclude locations that do or do not match a specific regex.
    if ($1 !~ /(Public$|Memorial$)/){
      print "Not valid location - skip\n";
      next;
    }
    
		$lname = $1;
		#$chunks[$i] =~ s/(\r\n){5,}//m; # Remove any group of 5 or more returns
		#$chunks[$i] =~ s/(\n){5,}//m; # Remove any group of 5 or more returns
		my @lines = split("\n",$chunks[$i]);
		#Get Date
		#print 'chunk->'.$chunks[$i];
		#print $lines[$startline]."\n";
		#this finds the starting line by finding the date that begins each notice  #Modified on June 7th 2010 because of new format
		for(my $a = 0; $lines[$a] !~ /^\d{1,2}-\d{1,2}-\d{1,2} \d{1,2}:\d{1,2}(AM|PM)$/; $a++){
			$startline = $a+1;
      #print $lines[$a]."line\n";
		}
		my $date = $lines[$startline];
    #print $startline." startline\n";
    
    #exit;
		#Get customer name
		$lines[$startline+2] =~ /^.{40}(.*)$/;
		my $pname = $1;

		#Get customer address
		$lines[$startline+3] =~ /^.{40}(.*)$/;
		my $addr1 = $1;
		
		#Remove leading and trailing spaces, and multiple spaces
		$addr1 =~ s/\s+/ /g;
		$addr1 =~ s/^\s//;
		$addr1 =~ s/\s$//;
		
		$lines[$startline+4] =~ /^.{40}(.*)$/;
		my $addr2 = $1;
		
		#strip out extra spaces.
		$addr2 =~ s/\s+/ /g;

		#Stip out commas and periods
		$addr2 =~ s/[,]//g;
		$addr2 =~ s/[.]//g;

		#Strip out ending US
		$addr2 =~ s/ US$//;
		
#		print "address to match -->>> ".$addr2."\n";
		#Grab City, State & zip
		$addr2 =~ /^((?:\w+\s?){1,6}) ([a-zA-Z]{2}) (\d{5}-?\d?\d?\d?\d?)/;
		
		my $city = $1;
		my $state = $2;
		my $zip = $3;
		
		#Strip out ending space in city name;
		#$city =~ s/\s+$//;

		#get customer phone
		$lines[$startline+5] =~ /^.{40}(.*)$/;
		my $phone = $1;
#		print "  -- --> D $date -- N $pname -- A1 $addr1 -- A2 $addr2 -- PN $phone \n";
		
		#check to see if a name is already in a hash, if not, add it.
		if( !$dupdata{$pname.$addr1} ){
		  $dupdata{$pname.$addr1} = 1;
      
      if($addr1 =~ m/^(\d+) /)
          {$hnum=$1;}  #Grab house number, will be blank for POs
      else{ #PO Box
        if($addr1 =~ m/BOX (\d+)/i)
          {$hnum=$1."99999999";}
        else
          {$hnum="";}
      }
      $dupdata{$pname.$addr1} = {
        name => "\U$pname",
        housenum => $hnum,
        addr1 => "\U$addr1",
        city => "\U$city",
        state => "\U$state",
        zip => $zip,
       };
    }
		#if this is a statement of charges, loop through charges and store them.
		#if this is a overdue notice - loop through notices - 
		#if this is a bill notice - loop through notices

		#chomp $chunks[$i];
		#store data in data hash
		$data{$lname} = $data{$lname}.$chunks[$i]."\n\n\n\n";
	}
	else {
#		print "   Branch not found\n";
	}
}

#produce the cvs file - Sort on zip, and then maybe house number
  #Create a seperate file for blank address's
  #Look for zip codes that are different than the city name, as long as the city
    #only has one zip.
#$addresslabels = "";
for $customerkey (sort { $dupdata{$a}{zip} <=> $dupdata{$b}{zip} or  $dupdata{$a}{housenum} <=> $dupdata{$b}{housenum}}keys %dupdata){

  if($dupdata{$customerkey}{zip} eq ""){ #Addresses that have no zip, put them in a seperate list
    $badcount++;
    $problems .= "\"".$thedate."\","
        ."\"".$dupdata{$customerkey}{name}."\","
        ."\"".$dupdata{$customerkey}{addr1}."\","
        ."\"".$dupdata{$customerkey}{city}."\","
        ."\"".$dupdata{$customerkey}{state}."\","
        ."\"".$dupdata{$customerkey}{zip}."\"\n";
  }  
  else{
    $goodcount++;
    $addresslabels .= "\"".$thedate."\","
        ."\"".$dupdata{$customerkey}{name}."\","
        ."\"".$dupdata{$customerkey}{addr1}."\","
        ."\"".$dupdata{$customerkey}{city}."\","
        ."\"".$dupdata{$customerkey}{state}."\","
        #."\"".$dupdata{$customerkey}{housenum}."\","
        ."\"".$dupdata{$customerkey}{zip}."\"\n";
  }

}

#print $addresslabels;


my $msg = MIME::Lite->new(
                From    =>'root@email.blarg',  #Edit this to set a valid sender address
                 To      =>$mailto,
                 Subject =>'Overdue Address File '.`date +%F`." Good:[".$goodcount."] Bad:[".$badcount."]",
                 Type    =>'multipart/mixed'
);
    ### Add the text message part:
    ### (Note that "attach" has same arguments as "new"):
    $msg->attach(Type     =>'TEXT',
                 Data     =>"CSV addresses from overdue notices.  \nThese files are intended to be used to send postcards to customers that have overdue material.
\n\nThe Overdue-Addresses-(date).csv file holds the addresses that seem to be in the correct format.
\n\nThe BAD-Overdue-Addresses file contains addresses that could not be parsed and don't have a zip code listed.  Please see if you can fix the address1 in the patron record if an address shows up there."
                 );
    ### Add the image part:
    $msg->attach(Type     =>'text/csv',
                 Filename =>'Overdue-Addresses-'.`date +%F`.'.csv',
                 Data => $addresslabels,
                 Disposition => 'attachment'
                 );
    if($badcount){
      $msg->attach(Type     =>'text/csv',
                 Filename =>'BAD-Overdue-Addresses-'.`date +%F`.'.csv',
                 Data => $problems,
                 Disposition => 'attachment'
                 );
    }
$msg->send;
