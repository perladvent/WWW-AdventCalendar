use strict;
use warnings;
use utf8;

use Test::More import => [qw( diag done_testing is ok )];
use DateTime ();

# Regression test: rendering an article whose body contains non-ASCII text
# used to die with "Can't decode ill-formed UTF-8 octet sequence" (a.k.a.
# "code points over 0xFF may not be mapped into in-memory file handles"),
# because body_html/body_html_for_rss reparsed an already-decoded string that
# still carried its =encoding utf-8 line.  ASCII-only bodies never tripped it.

use WWW::AdventCalendar::Article ();

# body_html and body_html_for_rss never dereference the calendar (only atom_id
# does), so a lightweight object that merely satisfies the type constraint is
# enough.  It is kept in a lexical because the attribute is a weak ref.
{
  package Test::StubCalendar;
  our @ISA = ('WWW::AdventCalendar');
  sub new { bless {}, shift }
}
my $calendar = Test::StubCalendar->new;

my $article = WWW::AdventCalendar::Article->new(
  date     => DateTime->new(year => 2025, month => 12, day => 1),
  title    => 'Snowman',
  topic    => 'Winter',
  author   => 'Some Author <author@example.com>',
  calendar => $calendar,
  body     => <<'POD',
A snowman ☃ enjoys a café in a naïve résumé.

=for web_only WEB ONLY: ☃

=for rss_only RSS ONLY: café

Fin.
POD
);

# The rendered output is short and deterministic, so assert it in full. The
# accented prose becomes HTML entities (é -> &eacute;, snowman -> &#x2603;),
# while the surviving raw =for html region keeps its characters literally.
# A regression would either die outright or produce double-encoded mojibake,
# and an exact comparison catches both, along with the region keep/drop.

# heredocs carry a literal é / snowman thanks to "use utf8"; each has a
# trailing newline the real output lacks, so chomp it off.
my $expected_web = <<"HTML";
<div class='pod'><p>A snowman &#x2603; enjoys a caf&eacute; in a na&iuml;ve r&eacute;sum&eacute;.</p>

WEB ONLY: ☃

<p>Fin.</p>

</div>
HTML

my $expected_rss = <<"HTML";
<div class='pod'><p>A snowman &#x2603; enjoys a caf&eacute; in a na&iuml;ve r&eacute;sum&eacute;.</p>

RSS ONLY: café

<p>Fin.</p>

</div>
HTML

chomp($expected_web, $expected_rss);

my $web = eval { $article->body_html };
ok(!$@, 'body_html does not die on a non-ASCII body') or diag $@;
is($web, $expected_web, 'web HTML renders correctly and keeps only web_only');

my $rss = eval { $article->body_html_for_rss };
ok(!$@, 'body_html_for_rss does not die on a non-ASCII body') or diag $@;
is($rss, $expected_rss, 'rss HTML renders correctly and keeps only rss_only');

done_testing;
