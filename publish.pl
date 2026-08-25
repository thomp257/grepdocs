#!/usr/bin/env perl
#
# Convert markdown files into an html destination.
#
use strict;
use warnings;
use Config::Tiny qw(new);
use File::Basename qw(basename);
use File::Copy qw(copy);
use File::Glob qw(:bsd_glob);
use File::Spec::Functions qw(catfile);
use Getopt::Long qw(:config bundling);
use Markdown::Perl;

our $VERSION = "1.20260825.0";
my $opt_verbose = 0;
my $config_file = catfile( ($ENV{"HOME"}, ".config"), "grepdocs.ini");

# Default ini config.
my $default_config = Config::Tiny->new({
  "MyDocs" => {
    "dir" => "/path/to/git/mydocs/docs",
    "dest" => "$ENV{'HOME'}/tmp/html",
  },
  "SomeTitle" => {
    "dir" => "/path/to/dir/docs",
    "dest" => "$ENV{'HOME'}/tmp/html",
  },
  "Version" => { "v" => 1 },
});


sub usage() {
  my $prog = basename($0);
  print <<EOL
  $prog <pattern>

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
  GetOptions (
    'config=s' => \$config_file,
    'default-config' => \$opt_print_default_config,
    'verbose|v+' => \$opt_verbose,
    'version' => sub { Getopt::Long::VersionMessage() },
    'help|h|-?' => sub { usage(); exit 0 },
  ) or die "Error with options\n";

  debug(2, "Verbose level: $opt_verbose");

  if ($opt_print_default_config) {
    print($default_config->write_string());
    exit 0;
  }

  # Map source markdown to destination.
  my %map = (
    "Test.md" => "/Docs",
    "Markdown.md" => "/Docs",
  );

  # # Dest paths.
  # my $dest_root = "$HOME/tmp";
  # my $dest_html = "/html";
  # my $dest = $dest_root . $dest_html . "/";

  # # Get source and destination.
  # my $dest = $map{$source} or die "Error: Bad source name";
}


sub get_markdown() {
  my $source = @_;
  # Get markdown content.
  open(my $fh, "<", $source) or die "Error: $!";
  # The first line is the title.
  my $title = <$fh>;
  # The rest is markdown.
  my $markdown = do { local $/; <$fh> };
  close($fh);
  # Add the title back to markdown.
  $markdown = $title . $markdown;
  chomp($title);

  return ($title, $markdown);
}


sub convert_to_html() {
  my ($title, $markdown) = @_;
  # Convert markdown to html.
  my $converter = Markdown::Perl->new();
  $converter->set_mode("cmark");
  my $content = $converter->convert($markdown);
  my $html = <<EOL
  <!DOCTYPE html>
  <html lang="en">
  <head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title</title>
  <style>
  code {
    background-color: #f6f8fa;
    color: #24292f;
    font-family: monospace;
    overflow-x: auto;
    white-space: pre;
  }
  pre {
    background-color: #f6f8fa;
    color: #24292f;
    padding: 16px;
    border-radius: 8px;
    padding: 16px 0;
    border: 1px solid #333333;
  }
  pre code {
    font-family: monospace;
    font-size: 85%;
    padding: 16px;
    line-height: 1.5;
    overflow-x: auto;
    white-space: pre;
  }
  </style>
  </head>
  <body>
  $content
  </body>
  </html>
EOL
;
  return $html
}


sub publish() {
  my ($source, $dest, $html) = @_;
  # Publish markdown file.
  my $md_dest = $dest . "/" . $source;
  print("Publish: $md_dest\n");
  #copy($source, $dest . $md_dest) or die "Error: Copy failed: $!";

  # Publish html file.
  my $html_filename = $source;
  $html_filename =~ s/\.md$/.html/;
  my $html_dest = $dest . "/" . $html_filename;
  print("Publish: $html_dest\n");

  #open($fh, ">", $dest . $html_dest) or die "Error: Open failed: $!";
  #print $fh $html;
  #close($fh);
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
}


main()
