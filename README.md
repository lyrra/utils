# Misc sysutils
---------------

  ## Scripts:

  - gitstatjson.pl -- make a json output of your list of git repos
  - tuerl.pl -- tool to quickly use EUnit (also: can test private functions outside of target-module)

  --------------

  ## tuerl.pl

  Run through all test files in a directory and call EUnit on them.

  Example
    src/hello.erl -- your target source that needs testing
    src/t/mycommon.erl -- text fixtures and utils for your testing
    src/t/t_01_foo.erl -- one of your files contaning test case

  FILE: src/hello.erl

    -module(hello).
    -export([hello_world]).
    -define(NAT, 123).
   
    hello_world() -> ?NAT.

  FILE: src/t/mycommon.erl

    is_natural (X) -> is_integer(X) and (X > 0).

  FILE: src/t/t_01_foo.erl

    # this file has tests for hello module
    file: ../hello.erl
    # below three lines are optional if you want to replace the targets headers(-export, -define, etc)
    pre:
    -define(NAT, "bar"). % override during test
    code:
   
    % see eunit docs for why end function with _test_, and ?_assert macro
    t_01_my_test_ () -> [?_assert(is_natural(hello_world))].

  At shell:

    $ cd t  # go into your test directory
    $ ./tuerl.pl -v --inc=mycommon.erl --erl="-pa .. -pa ../epgsql/ebin -pa ../jiffy/ebin"
    ...
    All 1 tests passed.

    Also check $? == 0 if you script tuerl.pl (zero if all tests passed).

  -----------------

  ## gitstatjson.pl

  convert git log statistics into json-data (usable with D3)

    Usage: echo -e \"/home/my/gitrepo1\\n/home/my/gitrepo2\" | gitstatjson.pl [-v|-v|-a|-H]
     -v be verbose (to stderr), -a include deleted/created files, -H hourly statistics
     --ef=<exclude_file> file with lines to exclude

    Example:  echo /home/my/git/linux | gitstatjson.pl -v -v --ef=excl > /var/www/git.json 2> log

  Exclude file format:

  --ef=exclude.txt

  exclude.txt:

      myrepo1:
        dummyfile
        data/dir/
      myrepo2:
        foobar

