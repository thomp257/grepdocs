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

# Inline module Config::Tiny.
{
  # Config::Tiny - Read/Write .ini style files with as little code as possible.
  package Config::Tiny;

  use strict;
  use 5.008001; # For the utf8 stuff.
  our $VERSION = '2.30';

  BEGIN {
    $Config::Tiny::errstr  = '';
  }

  # Create an object.
  sub new { return bless defined $_[1] ? $_[1] : {}, $_[0] }

  # Create an object from a file.
  sub read
  {
    my($class)           = ref $_[0] ? ref shift : shift;
    my($file, $encoding) = @_;

    return $class ->
      _error('No file name provided') if (! defined $file || ($file eq '') );

    # Slurp in the file.
    $encoding = $encoding ? "<:$encoding" : '<';
    local $/  = undef;

    open(my $CFG, $encoding, $file) or return $class ->
      _error( "Failed to open file '$file' for reading: $!" );
    my $contents = <$CFG>;
    close($CFG );

    return $class ->
      _error("Reading from '$file' returned undef") if (! defined $contents);

    return $class -> read_string( $contents );
  }

  # Create an object from a string.
  sub read_string
  {
    my($class) = ref $_[0] ? ref shift : shift;
    my($self)  = bless {}, $class;

    return undef unless defined $_[0];

    # Parse the file.
    my $ns      = '_';
    my $counter = 0;

    foreach ( split /(?:\015{1,2}\012|\015|\012)/, shift )
    {
      $counter++;

      # Skip comments and empty lines.
      next if /^\s*(?:\#|\;|$)/;

      # Remove inline comments.
      s/\s\;\s.+$//g;

      # Handle section headers.
      if ( /^\s*\[\s*(.+?)\s*\]\s*$/ )
      {
        # Create the sub-hash if it doesn't exist.
        # Without this sections without keys will not
        # appear at all in the completed struct.
        $self->{$ns = $1} ||= {};
        next;
      }

      # Handle properties.
      if ( /^\s*([^=]+?)\s*=\s*(.*?)\s*$/ )
      {
        if ( substr($1, -2) eq '[]' )
        {
          my $k = substr $1, 0, -2;
          $self->{$ns}->{$k} ||= [];
          return $self ->
            _error ("Can't mix arrays and scalars at line $counter")
              unless ref $self->{$ns}->{$k} eq 'ARRAY';
          push @{$self->{$ns}->{$k}}, $2;
          next;
        }
        $self->{$ns}->{$1} = $2;
        next;
      }

      return $self -> _error( "Syntax error at line $counter: '$_'" );
    }

    return $self;
  }

  # Save an object to a file.
  sub write
  {
    my($self)            = shift;
    my($file, $encoding) = @_;

    return $self ->
      _error('No file name provided') if (! defined $file or ($file eq '') );

    $encoding = $encoding ? ">:$encoding" : '>';

    # Write it to the file.
    my($string) = $self->write_string;

    return undef unless defined $string;

    open(my $CFG, $encoding, $file) or return $self ->
      _error("Failed to open file '$file' for writing: $!");
    print $CFG $string;
    close($CFG);

    return 1;

  }

  # Save an object to a string.
  sub write_string
  {
    my($self)     = shift;
    my($contents) = '';

    for my $section ( sort {
      (($b eq '_') <=> ($a eq '_')) || ($a cmp $b)
      } keys %$self )
    {
      # Check for several known-bad situations with the section
      # 1. Leading whitespace
      # 2. Trailing whitespace
      # 3. Newlines in section name.
      return $self ->
        _error("Illegal whitespace in section name '$section'")
          if $section =~ /(?:^\s|\n|\s$)/s;

      my $block = $self->{$section};
      $contents .= "\n" if length $contents;
      $contents .= "[$section]\n" unless $section eq '_';

      for my $property ( sort keys %$block )
      {
        return $self ->
          _error("Illegal newlines in property '$section.$property'")
            if $block->{$property} =~ /(?:\012|\015)/s;

        if (ref $block->{$property} eq 'ARRAY') {
          for my $element ( @{$block->{$property}} )
          {
            $contents .= "${property}[]=$element\n";
          }
          next;
        }
        $contents .= "$property=$block->{$property}\n";
      }
    }

    return $contents;

  }

  # Error handling.
  sub errstr { $Config::Tiny::errstr }
  sub _error { $Config::Tiny::errstr = $_[1]; undef }
}

# Start grepdocs.
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
