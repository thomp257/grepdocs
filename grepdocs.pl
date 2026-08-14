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
use Config::Tiny;

our $VERSION = "1.20260526.0";
my $verbose = 0;
my $config_file = catfile( ($ENV{"HOME"}, ".config"), "grepdocs.ini");
# Valid doc file extensions to search.
my $fileext_regex = join("|", qw(.md .markdown .txt .yaml .yml .sh .bash .conf
                                 .j2 .json .rst));
my $filter = "";
# Default ini config.
my $default_config = Config::Tiny->new({
  "MyDocs" => { "dir" => "/path/to/git/mydocs/docs" },
  "Title" => { "dir" => "/path/to/dir/docs" },
  "Version" => { "v" => 1 },
});


sub usage() {
  my $prog = basename($0);
  print <<EOL
  $prog <pattern>

  --edit|-e           Edit files with \$EDITOR instead of printing.

  --config <file>     Use this config file.
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
  my $opt_print_default_config = 0;
  my $opt_edit = 0;
  GetOptions (
    'edit|e' => \$opt_edit,
    'config=s' => \$config_file,
    'default-config' => \$opt_print_default_config,
    'verbose|v+' => \$verbose,
    'version' => sub { Getopt::Long::VersionMessage() },
    'help|h|-?' => sub { usage(); exit 0 },
  ) or die "Error with options\n";

  debug(2, "Verbose level: $verbose");
  debug(4, "OSNAME $OSNAME");

  if ($opt_print_default_config) {
    print($default_config->write_string());
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
      open(my $fh, '<', $file) or
        die "Cannot open '$file': $OS_ERROR";
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
    exec { $cmd[0] } @cmd or
      die "Cannot exec edit command: $OS_ERROR";
  }
}


sub get_config {
  my @dirs = ();
  debug("Parse config");
  my $ini_config = Config::Tiny->read($config_file) or
    die "Error: Config file: " . Config::Tiny->errstr;

  my $conf_ver = $ini_config->{"Version"}->{"v"} or
    die "Error: Config file: No valid Version found\n";
  if ($conf_ver != "1") {
    die "Error: Config file: Can only parse config Version v=1\n";
  }
  debug("Config ini Version v=$conf_ver");

  foreach my $section (keys %{$ini_config}) {
    next if $section eq "Version";
    my $title = $section;
    debug(2, "Title: '$title'");
    my $dir = $ini_config->{$section}->{"dir"} or
      die "Error: Config file: No dir found in section '$section'\n";
    debug(2, "Dir: '$dir'");
    push(@dirs, $dir);
  }
  return @dirs;
}


sub get_files {
  my $dir = shift;
  my @ret;

  debug(2, "Walk '$dir'");
  opendir(my $dh, $dir) or
    die "Cannot open dir '$dir': $OS_ERROR";
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
