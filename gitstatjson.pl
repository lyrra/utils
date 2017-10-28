#!/usr/bin/perl
# 20171028 larry initial

use strict;
use warnings;

my $verbose = 0;
my $gran = "day"; # granularity: hour, day

# Dont include created files (new code has either no brainpower (full of bugs) behind it, or is inherited (dont double-count))
# Deleted files can also distort for example in code rearrangements with a net code change in zero
my $skip_create_delete = 1;

my $magic = "_Zzz";
my $git = "git"; # Git command
my $gopt = "log --reverse --summary --numstat --pretty='$magic %ai %cn;%s'"; # options given to git command

my %exclude = ();

foreach my $arg (@ARGV){
  if($arg eq "-h" or $arg eq "--help"){
    print "Usage: echo -e \"/home/my/gitrepo1\\n/home/my/gitrepo2\" | gitstatjson.pl [-v|-v|-a|-H]\n";
    print " -v be verbose (to stderr), -a include deleted/created files, -H hourly statistics\n";
    print " --ef=<exclude_file> file with lines to exclude\n";
    exit(1);
  }elsif($arg eq "-v"){
    $verbose++;
  }elsif($arg eq "-a"){
    $skip_create_delete = 0;
  }elsif($arg eq "-H"){
    $gran = "hour";
  }elsif($arg =~ /--ef=(.*)/){
    open my $fh, '<', $1 or die "Cant open file [$1]";
    my $repo = "";
    while(my $line = <$fh>){ # here is the syntax where we parse the exclusion-file
      chomp $line;
      if($line =~ /^\s*(.*):\s*$/){ # a colon marks a repo-name
        $repo = $1;
      }else{ # other lines belongs to the current repo-name
        $line =~ s/^\s*(.*)/$1/; # remove prepending spaces
        push(@{$exclude{$repo}}, $line);
      }
    }
    close $fh;
  }
}

print STDERR "Verbose mode.\n" if $verbose;

if($verbose > 1){
  while(my($reponame, $k) = each %exclude){
    if($#{$exclude{$reponame}} >= 0){
      print STDERR "exclude lines in repo $reponame:\n";
      foreach my $x (@{$exclude{$reponame}}){
        print STDERR "    --->$x\n";
      }
    }
  }
}

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
    my $f = 0;
    #print STDERR "Searching for exclusion in repo [$repo]\n";
    foreach my $l (@{$exclude{$repo}}){
      #print STDERR "Maybe exclude [$repo] [$l] [$line]\n";
      if($line =~ /$l/){ $f = 1; last }
    }
    next if $f;
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
  my($repo, $line, $ex) = @_;
  my $currc = $hr{$repo}{currc}; # last/current commit
  print STDERR "$ex> $line\n" if $verbose > 1;
  if($line =~ /^$magic\s+(\d+-\d+-\d+\s+\d+:\d+:\d+)\s+(\+\d+)\s+(.*);(.*)/){
    my $date = $1;
    if($gran eq "hour"){
      $date =~ s/(\d+-\d+-\d+\s+\d+):.*/$1/;
    }else{ # default do daily buckets
      $date =~ s/(\d+-\d+-\d+)\s+.*/$1/;
    }
    print STDERR "date: [$date]\n" if $verbose > 1;
    $hr{$repo}{$date}{zone} = $2;
    $hr{$repo}{$date}{user} = $3;
    $hr{$repo}{$date}{subj} = $4;
    $hr{$repo}{currc} = $date; # pointer to last/current commit; KLUDGY way to store state; would need to separate working and final state
  }elsif($line =~ /\s*(\d+)\s+(\d+)\s+(.*)/){
    my $file = $3;
    $hr{$repo}{$currc}{file}{$file}{add}  += $1; # added lines
    $hr{$repo}{$currc}{file}{$file}{del}  += $2; # removed lines
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
        print STDERR "    total add/del: $date $add $del\n" if($verbose);
      }
    }
  }
}
