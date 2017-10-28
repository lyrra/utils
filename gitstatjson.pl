#!/usr/bin/perl
# 20171028 larry initial

use strict;
use warnings;

my $verbose = 0;

# Dont include created files (new code has either no brainpower (full of bugs) behind it, or is inherited (dont double-count))
# Deleted files can also distort for example in code rearrangements with a net code change in zero
my $skip_create_delete = 1;

my $magic = "_Zzz";
my $git = "git"; # Git command
my $gopt = "log --reverse --summary --numstat --pretty='$magic %ai %cn;%s'"; # options given to git command

foreach my $arg (@ARGV){
  if($arg eq "-h" or $arg eq "--help"){
    print "Usage: echo -e \"/home/my/repo1\n/home/my/repo2\" | git.pl [-v|-v|-a]\n";
    exit(1);
  }elsif($arg eq "-v"){
    $verbose++;
  }elsif($arg eq "-a"){
    $skip_create_delete = 0;
  }
}
print STDERR "Verbose mode.\n" if($verbose);

my %ha = (); # Activity across all repos and users
my %hr = (); # each repo state hash

while(my $dir = <STDIN>){
  # foreach line read from standard-input, change-dir into that line
  chomp $dir;
  chdir $dir or die "Can't CD into directory --->$dir<---";
  my $repo = $dir;
  $repo =~ s/.*\/(\w+)[\/]*$/$1/ if($repo =~ /\//); # pathname
  print STDERR "Reading repo dir:{$dir}, name:{$repo}\n" if $verbose;
  # read the git log output, and update the repo state hash
  open my $fh, '-|', "$git $gopt" or die "Cant run $git";
  while(my $line = <$fh>){
    chomp $line;
    update_repo_state($repo, $line);
  }
  close $fh;
  # Using the repo state hash, update the global state
}

create_summary_state();

# Finally convert global state into an JSON output

{
  my $n;
  print "{"; # output everything into a big json hash

  my @dates = sort keys %ha;

  # dump date vector
  print "\"dates\":[";
  $n = 0;
  foreach my $date (@dates){
    print "," if($n > 0);
    print "\"$date\"";
    $n++;
    print "\n" if($n % 4 == 0); # page friendly output
  }
  print "],";

  # dump total repo activity in added lines
  print "\n\"adds\":[";
  $n = 0;
  foreach my $date (@dates){
    my $add = $ha{$date}{add};
    print "," if($n > 0);
    print "$add";
    $n++;
    print "\n" if($n % 8 == 0);
  }
  print "],";

  # dump total repo activity in deleted lines
  print "\n\"dels\":[";
  $n = 0;
  foreach my $date (@dates){
    my $del = $ha{$date}{del};
    print "," if($n > 0);
    print "$del";
    $n++;
    print "\n" if($n % 8 == 0);
  }
  print "]";
  # close the big json hash
  print "}\n";
}

#### Subs

sub update_repo_state {
  my($repo, $line) = @_;
  my $currc = $hr{$repo}{currc}; # last/current commit
  print STDERR "> $line\n" if $verbose > 1;
  if($line =~ /^$magic\s+(\d+-\d+-\d+\s+\d+:\d+:\d+)\s+(\+\d+)\s+(.*);(.*)/){
    my $date = $1;
    $hr{$repo}{$date}{zone} = $2;
    $hr{$repo}{$date}{user} = $3;
    $hr{$repo}{$date}{subj} = $4;
    $hr{$repo}{currc} = $date; # pointer to last/current commit; KLUDGY way to store state; would need to separate working and final state
  }elsif($line =~ /\s*(\d+)\s+(\d+)\s+(.*)/){
    my $file = $3;
    $hr{$repo}{$currc}{file}{$file}{add}  = $1; # added lines
    $hr{$repo}{$currc}{file}{$file}{del}  = $2; # removed lines
  }elsif($line =~ /\s+delete mode \d+\s+(.*)/){
    my $file = $1;
    $hr{$repo}{$currc}{file}{$file}{delete} = 1; # mark file as created
  }elsif($line =~ /\s+create mode \d+\s+(.*)/){
    my $file = $1;
    $hr{$repo}{$currc}{file}{$file}{create} = 1; # mark file as created
  }
}

sub create_summary_state {
  # dump the repo state in %hr into global state %ha
  while(my($repo, $commitsh) = each %hr){
    # repo
    print STDERR "Repository: $repo\n" if $verbose;
    my @keys = sort keys %{$commitsh}; # all dates
    foreach my $date (@keys){
      if($date ne "currc"){
        my $add = 0;
        my $del = 0;
        print STDERR "  $date -------------------------\n" if $verbose;
        while(my($name, $comh) = each %{$$commitsh{$date}}){
          if($name eq "file"){
            while(my($k, $v) = each %{$comh}){
              print STDERR "    File $k\n" if $verbose;
              while(my($k, $v) = each %{$v}){
                print STDERR "      $k: $v\n" if $verbose;
              }
              if( $skip_create_delete == 0 or
                 ($skip_create_delete == 1 and (!defined($$v{create})) and (!defined($$v{delete})))){
                $add += $$v{add};
                $del += $$v{del};
              }
            }
          }else{
            print STDERR "    $name => $comh\n" if $verbose;
          }
        }
        $ha{$date}{add} += $add;
        $ha{$date}{del} += $del;
      }
    }
  }
}
