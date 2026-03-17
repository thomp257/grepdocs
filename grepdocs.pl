#!/usr/bin/env perl
#
# Search docs dirs.
#
# Copyright 2025 Robert Thompson <thomp@64bitrot.net>
# AGPL-3.0-or-later
use strict;
use warnings;
use English;
no warnings qw(experimental::builtin);
use builtin qw(trim);
use File::Basename qw(basename);
use File::Spec::Functions qw(catfile);
use Getopt::Long qw(:config bundling);

our $VERSION = "1.20260217.0";
my $config_file = catfile( ($ENV{"HOME"}, ".config"), "grepdocs.conf");
my $opt_print_default_config = 0;
my $opt_edit = 0;
my $verbose = 0;
# Valid doc file extensions to search.
my $fileext_regex = join("|", qw(.md .markdown .txt));
my $filter = "";


sub usage() {
  my $prog = basename($0);
  print <<EOL
  $prog <pattern>

  --edit|-e           Edit files with \$EDITOR instead of printing.

  --config            $prog config file.
                      Default: '$config_file'.

  --default-config    Print a default config.

  --verbose|-v        Add verbosity to output.
  --version
  --help|-h
EOL
  ;
}


sub main() {
  # Args
  GetOptions (
    'edit|e' => \$opt_edit,
    'config=s' => \$config_file,
    'default-config' => \$opt_print_default_config,
    'verbose|v+' => \$verbose,
    'version' => sub { Getopt::Long::VersionMessage() },
    'help|-h|-?' => sub { usage(); exit 0 },
  );
  debug(2, "Verbose level: $verbose");
  debug(4, "OSNAME $OSNAME");

  if ($opt_print_default_config) {
    print("A Title:/path/to/docs/dir\n");
    print("Second Title:/another/path/to/docs\n");
    print("Third:/a/path/with/colon/C:/is/valid\n");
    print("# Line commented out:/nowhere/none\n");
    print("Everything after the first colon is the path:C:\\\\path\n");
    print("The title cannot contain a colon:/sorry\n");
    exit 0;
  }

  # Data
  my $search_for = trim(join(".*", @ARGV));
  debug("Arg search_for: '$search_for'");
  my @dirs = ();
  my @files = ();
  my @filename_results = ();
  my @search_results = ();
  my @results;

  # Get files from each dir in config
  @dirs = get_config();
  debug("Found " . scalar(@dirs) . " dirs in config");

  debug("Get files");
  foreach my $dir (@dirs) {
    push(@files, get_files($dir));
  }

  debug("Search");
  if (length($search_for) == 0) {
    debug(2, "Search is blank so return all results");
    @results = @files;
  } else {
    foreach my $file (@files) {
      debug(2, "Search file: $file");

      debug(4, "Search file name: $file");
      if (basename($file) =~ /$search_for/i) {
        debug("Filename match");
        push(@filename_results, $file);
        next;
      }

      debug(4, "Search file content: $file");
      open(my $fh, '<', $file) or die "Cannot open '$file': $OS_ERROR\n";
      while (my $line = <$fh>) {
        if ($line =~ /$search_for/i) {
          debug("Content match");
          push(@search_results, $file);
          last;
        }
      }
      close($fh);
    }
    # Print filenames first.
    @results = (@filename_results, @search_results);
  }

  # Output.
  if (not @results) {
    print("No results found.\n");
    return 0;
  }

  if (not $opt_edit) {
    debug("Print results" . "\n");
    foreach my $res (@results) {
      print "$res\n";
    }
  } else {
    # Build the edit command.
    my @cmd;
    my $ed = $ENV{"EDITOR"} || '/usr/bin/vim';
    if ($ed =~ /vi[m]?$/ and scalar(@search_results) >= 1) {
      # Only if file contents were found, have vim search for
      # the same pattern (starting from line 1).
      @cmd = ( $ed, "-c", "1 /$search_for", "--", @results);
    } else {
      @cmd = ( $ed, "--", @results);
    }
    debug("Exec command. bye bye");
    debug(2, "cmd: @cmd");
    exec { $cmd[0] } @cmd or die "Cannot exec edit command: $OS_ERROR";
  }
}


sub get_config {
  my @dirs = ();
  debug("Parse config");
  open(my $fh, "<", $config_file) or
    die "Cannot open config: '$config_file': $OS_ERROR\n";
  while (my $line = <$fh>) {
    chomp($line);
    # Skip comments.
    next if $line =~ /^\s*#/;
    # Grab the first item as title. Everything else is the dir path.
    my ($title, $dir) = split(/:/, $line, 2);
    debug(2, "Title: '$title'");
    debug(2, "Dir: '$dir'");
    push(@dirs, $dir);
  }
  return @dirs;
}


sub get_files {
  my $dir = shift;
  my @ret;

  debug(2, "Walk '$dir'");
  opendir(my $dh, $dir) || die "Cannot open dir '$dir': $OS_ERROR";
  foreach my $file (readdir($dh)) {
    next if (grep(/^$file$/, (".",  "..", ".git")));
    # Get abs_path for this file.
    my $this_file = catfile($dir, $file);
    if (-d $this_file) {
      # Recursive walk down dir.
      push(@ret, get_files($this_file));
    } elsif (-f $this_file) {
      debug(3, "Get file '$file'");
      if ($file =~ /$fileext_regex$/) {
        push(@ret, $this_file);
      }
    }
  }
  closedir($dh);
  debug(2, "Walk complete '$dir'");
  return @ret;
}


sub debug {
  my ($level, $msg) = @_;
  if (not $msg) {
    $msg = $level;
    $level = 1;
  }
  if ($verbose >= $level) {
    print "Debug$level: $msg\n"
  }
}


main()
