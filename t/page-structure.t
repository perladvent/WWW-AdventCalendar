use strict;
use warnings;

use Test::More import => [qw( done_testing is like subtest unlike )];

use Calendar::Simple qw( calendar );
use Color::Palette ();
use DateTime ();
use File::Temp ();

use WWW::AdventCalendar ();
use WWW::AdventCalendar::Article ();

# Every generated page must be HTML5 with a language declared on the root
# element, and must have exactly one <h1>.  On article pages that <h1> is the
# article title, so the site brand in the shared header must not be one too.

my $tmp = File::Temp->newdir;

my $calendar = WWW::AdventCalendar->new(
  title         => 'Test Calendar',
  uri           => 'https://example.com/',
  editor        => 'Ed Itor',
  year          => 2025,
  today         => '2025-12-02',
  article_dir   => "$tmp",
  output_dir    => "$tmp",
  share_dir     => 'share',
  color_palette => Color::Palette->new(colors => {}),
);

my $article = WWW::AdventCalendar::Article->new(
  date     => DateTime->new(year => 2025, month => 12, day => 1),
  title    => 'Snowman',
  topic    => 'Winter',
  author   => 'Some Author <author@example.com>',
  calendar => $calendar,
  body     => "Hello.\n\n=head1 A section\n\nMore.\n",
);

my %month = map {; $_ => DateTime->new(year => 2025, month => 12, day => $_) }
  1 .. 31;

my %page = (
  article => $calendar->_masonize('/article.mhtml', {
    article => $article,
    date    => $article->date->ymd,
    year    => 2025,
    https   => 0,
  }),
  calendar => $calendar->_masonize('/calendar.mhtml', {
    today    => $calendar->today,
    year     => 2025,
    month    => \%month,
    calendar => scalar calendar(12, 2025, 0),
    articles => { $article->date->ymd => $article },
  }),
  patience => $calendar->_masonize('/patience.mhtml', {
    days => '3 days',
    year => 2025,
  }),
);

for my $name (sort keys %page) {
  my $html = $page{$name};

  subtest "$name page" => sub {
    like $html, qr/\A<!DOCTYPE html>\n/, 'HTML5 doctype';
    unlike $html, qr/XHTML 1\.1/, 'no XHTML 1.1 doctype';
    like $html, qr/<html\b[^>]*\blang="en"/, 'lang="en" on <html>';

    my @h1 = $html =~ m{<h1\b[^>]*>(.*?)</h1>}gs;
    is scalar @h1, 1, 'exactly one <h1>';

    if ($name eq 'article') {
      is $h1[0], 'Snowman', 'the <h1> is the article title';
      like $html,
        qr{<div class="brand"><a href="index\.html">Test Calendar</a></div>},
        'site brand is a div on article pages';
    } else {
      like $h1[0], qr{Test Calendar}, 'the <h1> is the site brand';
    }
  };
}

subtest 'stylesheet' => sub {
  # Supply a value for every colour the stylesheet asks for.
  my $src   = do { local (@ARGV, $/) = 'share/templates/style.css'; <> };
  my %color = map {; $_ => '#000' } $src =~ /\$color\{(\w+)\}/g;

  my $css = $calendar->_masonize('/style.css', { color => \%color });

  like $css, qr/^h1, #header \.brand \{/m, 'brand styled like an <h1>';
  like $css, qr/^#header \.brand a \{/m, 'brand link colour targets .brand';
};

done_testing;
