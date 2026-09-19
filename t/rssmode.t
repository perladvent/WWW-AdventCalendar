use strict;
use warnings;

use Test::More;

use Pod::Elemental;
use Pod::Elemental::Transformer::RSSMode;

# The transformer takes a Pod document containing =for web_only and
# =for rss_only regions and, depending on web_mode, drops the region that
# does not apply and rewrites the surviving region to a plain =for html.

my $POD = <<'POD';
=pod

Intro paragraph.

=for web_only WEBVERSION

=for rss_only RSSVERSION

=for html PLAINHTML

Outro paragraph.

=cut
POD

sub transformed {
  my ($web_mode) = @_;
  my $doc = Pod::Elemental->read_string($POD);
  Pod::Elemental::Transformer::RSSMode->new(web_mode => $web_mode)
    ->transform_node($doc);
  return $doc->as_pod_string;
}

subtest 'the transformer wiring' => sub {
  ok(
    Pod::Elemental::Transformer::RSSMode->does('Pod::Elemental::Transformer'),
    'consumes the Pod::Elemental::Transformer role',
  );

  is(
    Pod::Elemental::Transformer::RSSMode->new->web_mode,
    0,
    'web_mode defaults to 0 (the RSS view)',
  );
};

subtest 'web_mode => 1 keeps web_only, drops rss_only' => sub {
  my $out = transformed(1);

  like($out,   qr/WEBVERSION/,  'web_only content survives');
  unlike($out, qr/RSSVERSION/,  'rss_only content is removed');

  unlike($out, qr/=for \s+ web_only/x, 'no =for web_only remains');
  unlike($out, qr/=for \s+ rss_only/x, 'no =for rss_only remains');

  like($out, qr/=for \s+ html \s+ WEBVERSION/x,
    'surviving web_only region was rewritten to =for html');
};

subtest 'web_mode => 0 keeps rss_only, drops web_only' => sub {
  my $out = transformed(0);

  like($out,   qr/RSSVERSION/,  'rss_only content survives');
  unlike($out, qr/WEBVERSION/,  'web_only content is removed');

  unlike($out, qr/=for \s+ web_only/x, 'no =for web_only remains');
  unlike($out, qr/=for \s+ rss_only/x, 'no =for rss_only remains');

  like($out, qr/=for \s+ html \s+ RSSVERSION/x,
    'surviving rss_only region was rewritten to =for html');
};

subtest 'unrelated content is left alone' => sub {
  for my $web_mode (0, 1) {
    my $out = transformed($web_mode);
    like($out, qr/Intro paragraph\./,   "web_mode=$web_mode: intro prose kept");
    like($out, qr/Outro paragraph\./,   "web_mode=$web_mode: outro prose kept");
    like($out, qr/PLAINHTML/,           "web_mode=$web_mode: pre-existing =for html kept");
    # a pre-existing =for html must not itself be duplicated or dropped
    my $html_count = () = $out =~ /PLAINHTML/g;
    is($html_count, 1, "web_mode=$web_mode: pre-existing =for html appears exactly once");
  }
};

done_testing;
