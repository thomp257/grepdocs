package grepdocs;
use strict;
use v5.12;
use base "Exporter";
use English;
use Config::Tiny;
use File::Spec::Functions qw(catfile);

our @EXPORT = qw($VERSION $config_file $opt_verbose $default_config
                 get_config get_dirs get_files get_sections debug);

our $VERSION = "1.20260827.0";
our $config_file = catfile( ($ENV{"HOME"}, ".config"), "grepdocs.ini");
our $default_config = Config::Tiny->new({
  "MyDocs" => {
    "dir" => "/path/to/git/mydocs/docs",
    "publish" => "$ENV{'HOME'}/tmp/html",
  },
  "SectionName" => {
    "dir" => "/path/to/markdown/files",
    "publish" => "$ENV{'HOME'}/tmp/html",
  },
  "SectionName/section" => {
    "dir" => "/path/to/markdown/some_section",
    "publish" => "$ENV{'HOME'}/tmp/html",
  },
  "GrepOnly" => {
    "dir" => "/path/to/git/foo",
  },
  "Version" => { "v" => 2 },
});
our $opt_verbose = 0;


sub get_config {
  debug("Parse config");
  my $ini_config = Config::Tiny->read($config_file) or
    die "Error: Config file: " . Config::Tiny->errstr;

  my $conf_ver = $ini_config->{"Version"}->{"v"} or
    die "Error: Config file: No valid Version found. Bad config?\n";
  if ($conf_ver > 2 || $conf_ver <= 0) {
    die "Error: Config file: Can only parse config Version 1 or 2\n";
  }
  debug("Config ini Version v=$conf_ver");

  return $ini_config;
};


sub get_sections {
  debug("Get sections");
  my $ini_config = shift;

  my @sections = ();
  foreach my $section (keys %{$ini_config}) {
    next if $section eq "Version";
    debug(2, "Section '$section'");
    push(@sections, $section);
  }
  return @sections;
}


sub get_dirs {
  debug("Get dirs");
  my $ini_config = shift;

  my @dirs = ();
  foreach my $section (get_sections $ini_config) {
    my $dir = $ini_config->{$section}->{"dir"} or
      die "Error: Config file: No dir found in section '$section'\n";
    debug(2, "Dir: '$dir'");
    push(@dirs, $dir);
  }
  return @dirs;
};


sub get_files {
  my $dir = shift;
  my $fileext_regex = shift;
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
  if ($opt_verbose >= $level) {
    print "Debug$level: $msg\n"
  }
};

1;
