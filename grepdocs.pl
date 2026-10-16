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
use Getopt::Long qw(:config bundling);
use grepdocs;

# Valid doc file extensions to search.
my $fileext_regex = join("|", qw(.md .markdown .txt .yaml .yml .sh .bash .conf
                                 .j2 .json .rst .py .pl));
my $opt_filter = "";
my $prog = basename($0);


sub usage() {
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
    'verbose|v+' => \$opt_verbose,
    'version' => sub { print "$prog $VERSION\n"; exit 0 },
    'help|h|-?' => sub { usage(); exit 0 },
  ) or die "Error with options\n";

  debug(2, "Verbose level: $opt_verbose");
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
  my $ini_config = get_config();
  @dirs = get_dirs($ini_config);
  debug("Found " . scalar(@dirs) . " dirs in config");

  debug("Get files");
  foreach my $dir (@dirs) {
    push(@files, get_files($dir, $fileext_regex));
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
        if ( (! grep { $_ eq $file } @filename_results) &&
             (! grep { $_ eq $file } @search_results) ) {
          push(@filename_results, $file);
        }
        next;
      }

      debug(4, "Search file content: $file");
      open(my $fh, '<', $file) or
        die "Cannot open '$file': $OS_ERROR";
      while (my $line = <$fh>) {
        if ($line =~ /$search_for/i) {
          debug("Content match");
          if ( (! grep { $_ eq $file } @filename_results) &&
               (! grep { $_ eq $file } @search_results) ) {
            push(@search_results, $file);
          }
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


main()
