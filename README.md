Misc sysutils
=============

  gitstatjson.pl
  --------------

  convert git log statistics into json-data (usable with D3)

    Usage: echo -e \"/home/my/gitrepo1\\n/home/my/gitrepo2\" | gitstatjson.pl [-v|-v|-a|-H]
     -v be verbose (to stderr), -a include deleted/created files, -H hourly statistics
     --ef=<exclude_file> file with lines to exclude

  Exclude file format:

  --ef=exclude.txt

  exclude.txt:

    | myrepo1:
    |   dummyfile
    |   data/dir/
    | myrepo2:
    |   foobar

