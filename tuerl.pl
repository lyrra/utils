#!/usr/bin/perl

my $erlc = "erlc"; # program used to compile erlang code
my $erl = "erl -noshell -noinput"; # program used to run erlang beams
my $mask = "t_*erl"; # use any files that matches, as test seeds
my $verbose = 0;     # Test verbosity

my $gname = 0;
my $incfile = 0;
my $erladd = "";
foreach my $arg (@ARGV){
  chomp $arg;
  if($arg =~ /--inc=(.*)/){
    $incfile = $1;
  }elsif($arg =~ /--erl=(.*)/){
    $erladd = $1;
  }elsif($arg eq "-v"){
    $verbose++;
  }elsif($arg eq "-h" or $arg eq "--help"){
    print "Usage ./tuerl.pl --inc=common.erl --erl='-pz .. -pa ../epgsql/ebin -pa ../jiffy/ebin'\n";
    exit 1;
  }
}

my @testfiles = `ls $mask`;

foreach my $testfile (@testfiles){
  chomp $testfile;
  print "Compiling test $testfile\n" if $verbose;
  comp_file($testfile, "t"); # assemble target and test source pieces into t.erl
  print "Target/Erlang compile frankenized assemlby\n" if $verbose;
  comp_src("t.erl");
  print "Run tests\n" if $verbose;
  run_eunit("t", $testfile);
}

sub run_eunit
{
  my($src, $name) = @_;
  my $cmd = "$erl $erladd -eval 'RC=case t:test()of ok->0;_->1 end,init:stop(RC)'";
  print $cmd . "\n" if $verbose;
  system($cmd);
  if($? != 0){
    die "FAIL $name\n";
  }
}

sub comp_src
{
  my($src) = @_;
  system("$erlc $src");
}

sub comp_file
{
  my($testfile, $outname) = @_;
  my $codefile = 0;
  my @testprea = ();
  my @testcode = ();
  my @targprea = ();
  my @targcode = ();

  open my $fh, '<', $testfile or die "Cant open file: $testfile, reason: $!";
  my $pre = 0;
  while($line = <$fh>){
    if($line =~ /^\s*#/){ # Comment line, ignore!
    }elsif($line =~ /^file:\s*(.*)/){
      chomp $line;
      $codefile = $1;
    }elsif($line =~ /^pre:/){
      $pre = 1;
    }elsif($line =~ /^code:/){
      $pre = 0;
    }else{
      if($pre){
        push(@testprea, $line);
      }else{
        push(@testcode, $line);
      }
    }
  }
  close $fh;
  if($codefile){
    print "Loading target code from file --->$codefile<---\n" if $verbose;
    open my $ih, '<', $codefile or die "Cant open file: $codefile, reason: $!";
    my $prea = 1;
    while($line = <$ih>){
      next if($line =~ /^-module/);  # ignore -module declaration
      if($line =~ /.*\)\s*->/){$prea = 0;}  # boilerplate finished, code from here and on
      if($prea){
        push(@targprea, $line); # preamble, -include -export
      }else{
        push(@targcode, $line); # normal code line
      }
      print $fh $line;
    }
    close $ih;
  }

  # write output file
  open $fh, '>', "$outname.erl" or die "Cant open file for write, reason: $!";
  print $fh "-module($outname).\n";
  print $fh "-include_lib(\"eunit/include/eunit.hrl\").\n\n";
  print "Using test-preamble: $#testprea\n" if $verbose;
  if($#testprea == -1){ # no test preamble
    print $fh "%%%% Target preamble\n\n";
    foreach my $line (@targprea){
      print $fh $line;
    }
  }else{
    print $fh "\n%%%% Test preable\n\n";
    foreach my $line (@testprea){
      print $fh $line;
    }
  }
  print $fh "\n%%%% Target code\n\n";
  foreach my $line (@targcode){
    print $fh $line;
  }
  if($incfile){
    print $fh "\n%%%% Test common/include code\n\n";
    open my $ih, '<', $incfile or die "Cant open file: $incfile, reason: $!";
    while($line = <$ih>){
      print $fh $line;
    }
    close $ih;
  }
  print $fh "\n%%%% Test code\n\n";
  foreach my $line (@testcode){
    print $fh $line;
  }
  close $fh;
}
