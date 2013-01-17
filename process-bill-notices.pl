#!/usr/bin/perl
use Mail::Sendmail;
use MIME::Lite;
use Mail::Internet;

my %data;
my %dupdata; #Duplicate Data Hash
my %alldata; #Stores all the address information
my $lname; 

#What is the max number of items to include.  If there are over this number of items, then the notice will need to be dealt with manually.
use constant MAXITEMS => 19;
my $oversized; #oversized notices, sent seperately.
my $addresslabels = '"date","name","address","city","state","zip","TotalAmount","NumberItems"';

foreach (my $c=1;$c<=MAXITEMS ; $c+=1){
	$addresslabels .= ",\"title$c\""
		.",\"type$c\""
		.",\"location$c\""
		.",\"barcode$c\""
		.",\"cost$c\"";
		
}
$addresslabels .= "\n";

#Email address to send CSV file to
my $mailto = 'notice@email.blarg';

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

#New Notice Format
@chunks = split(/^(1|2|10):(\d{1,3})/sm,$bodystring);

#Done with bodystring;
undef $bodystring;
print `date`;
my $thedate = `date "+%m-%d-%Y %r"`;
$thedate =~ s/\n//; #get rid of newline
print "Number of chunks is ->".scalar(@chunks)."\n";

my $startline = 0;

#Print out the sequence number and phone for each notice.
for (my $i = 0; $i < scalar(@chunks) -1; $i += 3){
	#print "I is $i\n";
	#print "  Sequence is ".$chunks[$i+2]."\n";
	#print "  Phone is ".$chunks[$i+2]."\n";
	#grab branch name from notice
	#print $chunks[$i];
	if ($chunks[$i] =~ /^([a-zA-Z ]+) Library/m){ 
		#assign each notice to a branch and add to a data structure
		#print "   library is -> $1 \n";
		$lname = $1;
		#$chunks[$i] =~ s/(\r\n){5,}//m; # Remove any group of 5 or more returns
		#$chunks[$i] =~ s/(\n){5,}//m; # Remove any group of 5 or more returns
		my @lines = split("\n",$chunks[$i]);
		#Get Date
		
		#print $lines[$startline]."\n";
		#this finds the starting line by finding the date that begins each notice  #Modified on June 7th 2010 because of new format
		for(my $a = 0; $lines[$a] !~ /^\d{1,2}-\d{1,2}-\d{1,2} \d{1,2}:\d{1,2}(AM|PM)$/; $a++){
			$startline = $a+1;
		}
		my $date = $lines[$startline];

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
		
		#print "address to match -->>> ".$addr2."\n";
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
		#print "  -- --> D $date -- N $pname -- A1 $addr1 -- A2 $addr2 -- PN $phone \n";
		
    
		#check to see if a name is already in a hash, if not, add it.
		#if( !$dupdata{$pname.$addr1} ){
		#  $dupdata{$pname.$addr1} = 1;
		 # print "$pname\n$addr1\n$addr2\n\n";
		  #$addresslabels = $addresslabels."\"\U$pname\",\"\U$addr1\",\"\U$city\",\"\U$state\",\"\U$zip\"";
		
		#if this is a statement of charges, loop through charges and store them.
		#if this is a overdue notice - loop through notices - 
		#if this is a bill notice - loop through notices

		$chunks[$i] =~ m/(ITEM.*Amount\n(.*)\n\s+TOTAL[\$](\d{1,6}\.\d{2}))/sm;
    my $bills = $2;
    my $totalamount = $3;
    $bills =~ s/["']//g;
		#print "\nOverdue Items --->\n$bills\n\n\n";
    #$addresslabels .= ",\"$bills\",\"$totalamount\"\n";
    
    if (!$alldata{$pname.$addr1}){
      $alldata{$pname.$addr1} = {
        name => "\U$pname",
        addr1 => "\U$addr1",
        city => "\U$city",
        state => "\U$state",
        zip => $zip,
        items => $bills,
        total => $totalamount,
        };
    }
    else {
      #add to a hash
      $alldata{$pname.$addr1}{items} .= "\n".$bills;
      $alldata{$pname.$addr1}{total} += $totalamount;
      }
    
    #}
		#chomp $chunks[$i];
		#store data in data hash
		#$data{$lname} = $data{$lname}.$chunks[$i]."\n\n\n\n";
	}
	else {
		#print "   Branch not found\n";
	}
}

my $CRLF = "\015\012";
for $customerkey (sort { $alldata{$a}{city} cmp $alldata{$b}{city} or $alldata{$a}{addr1} cmp $alldata{$b}{addr1} }keys %alldata){
  #Format the total amount correctly.
  if($alldata{$customerkey}{total} !~ m/[$]\d{1,5}[.]\d{2}/){
    #Add $ and cents
    $alldata{$customerkey}{total} = $alldata{$customerkey}{total}.'.00';
    }
  if((scalar(split("\n",$alldata{$customerkey}{items}))/2)>16){ #If more than 16 items, place in seperate file.
    $oversized .= $thedate."\n\n".
      $alldata{$customerkey}{name}."\n".
      $alldata{$customerkey}{addr1}."\n".
      $alldata{$customerkey}{city}." ".
      $alldata{$customerkey}{state}."  ".
      $alldata{$customerkey}{zip}."\n\n".
      "Number of items: ".(scalar(split("\n",$alldata{$customerkey}{items}))/2)."\n".
      "Total Amount Owed: ".$alldata{$customerkey}{total}."\n\n\n".
      $alldata{$customerkey}{items}."\n\n\n\n\n";
    
  }
  else {
  #print $customerkey." zip = ".$alldata{$customerkey}{zip}."\n";
  #print "-----------------> ".$alldata{$customerkey}{items}."\n";
  #Replace LF with  CR LF
#  $alldata{$customerkey}{items} =~ s/\n/$CRLF/g;
  $addresslabels .= "\"".$thedate."\","
  ."\"".$alldata{$customerkey}{name}."\","
	."\"".$alldata{$customerkey}{addr1}."\","
	."\"".$alldata{$customerkey}{city}."\","
	."\"".$alldata{$customerkey}{state}."\","
	."\"".$alldata{$customerkey}{zip}."\","
	."\"\$".$alldata{$customerkey}{total}."\"";
	#."\"".$alldata{$customerkey}{items}."\"\n";
	

	my @ia = split("\n",$alldata{$customerkey}{items});
	$addresslabels .= ",\"".(scalar(@ia)/2)."\",";
	foreach $iaa (@ia){
		if($iaa =~ m/^(\w.*)$/){
			#print "----->>>$1\n";
			$addresslabels .= "\"".$1."\",";
		}
		elsif($iaa =~ m/^  (REPLACEMENT|LOST) (.*) (\d{14})\.+(\$\d{1,6}\.\d\d)$/){
			#print "---------->$1 ----->$2 ------>$3 --------->$4\n";
			$addresslabels .= "\"".$1."\",";
			$addresslabels .= "\"".$2."\",";
			$addresslabels .= "\"b".$3."\",";
			$addresslabels .= "\"".$4."\",";
		}
	
	
	
	}
	
	#Fill up the rest of the row with blank lines, this is to see if it fixes the click2mail merge issue
	#for ($j =2;$j <= (MAXITEMS - (scalar(@ia)/2));$j+=1){
	#	$addresslabels .= '" "," "," "," "," ",';
	#}
	$addresslabels .= "\n";
}
}
#print $addresslabels;
  
my $msg = MIME::Lite->new(
                From    =>'root@email.blarg', #enter valid sender address
                 To      =>$mailto,
                 Subject =>'Bills Address File '.`date +%F`,
                 Type    =>'multipart/mixed'
);
    ### Add the text message part:
    ### (Note that "attach" has same arguments as "new"):
    $msg->attach(Type     =>'TEXT',
                 Data     =>"CSV addresses from notices"
                 );
    ### Add the cvs part:
    $msg->attach(Type     =>'text/csv',
                 Filename =>'Bill-Addresses-'.`date +%F`.'.csv',
                 Data => $addresslabels,
                 Disposition => 'attachment'
                 );

if($oversized){
    $msg->attach(Type     =>'TEXT',
                 Filename =>'Bill-Large-'.`date +%F`.'.txt',
                 Data     =>$oversized,
                 Disposition => 'attachment'
                 );
}
$msg->send;
