# -*- mode: perl -*-
use strict;
use warnings;

use Cwd;
use File::Slurp qw/ write_file /;
use File::Spec::Functions qw/ catfile /;
use Git::Repository qw(Log::Mailmap);
use Test::Git;
use Test::More;

$ENV{GIT_AUTHOR_EMAIL}    = 'author@example.com';
$ENV{GIT_AUTHOR_NAME}     = 'Author Name';
$ENV{GIT_COMMITTER_EMAIL} = 'committer@example.com';
$ENV{GIT_COMMITTER_NAME}  = 'Committer Name';

{
  my $r = test_repository;

  {
    my $f = 'hw.txt';
    write_file(catfile($r->work_tree, $f), 'hello, world');
    $r->run(add => $f);
    $r->run(commit => -m => "adds $f");
  }

  can_ok($r, 'log_mailmap');

  {
    my $it = $r->log_mailmap();
    can_ok($it, 'mailmap');
    while (my $log = $it->next) {
      can_ok($log, qw(commit));
      my ($an, $ae, $cn, $ce) =
        map { $r->run(qw/log -1 --use-mailmap/, "--pretty=$_", $log->commit) }
        qw/ %aN %aE %cN %cE /;
      is($log->author_name, $an);
      is($log->author_email, $ae);
      is($log->committer_name, $cn);
      is($log->committer_email, $ce);
    }
  }

  my $mailmap = <<'END';
an <a@example.org> Author Name <author@example.com>
cn <c@example.org> Committer Name <committer@example.com>
END

  {
    my $it = $r->log_mailmap();
    $it->mailmap->from_string(mailmap => $mailmap);
    while (my $log = $it->next) {
      can_ok($log, qw(commit));
      is($log->author_name, 'an');
      is($log->author_email, 'a@example.org');
      is($log->committer_name, 'cn');
      is($log->committer_email, 'c@example.org');
    }
  }

  $r->run(config => 'log.mailmap' => 'true');

  {
    my $file = catfile($r->work_tree, '.mailmap');
    write_file($file, $mailmap);
    my $it = $r->log_mailmap;
    while (my $log = $it->next) {
      is($log->author_name, 'an');
      is($log->author_email, 'a@example.org');
      is($log->committer_name, 'cn');
      is($log->committer_email, 'c@example.org');
    }
  }

  $mailmap =~ s/^([ac]n)/${1}2/gm;

  {
    my $file = catfile($r->work_tree, 'mailmap.txt');
    write_file($file, $mailmap);
    $r->run(add => $file);
    $r->run(commit => '-m' => "adds $file");
    $r->run(config => 'mailmap.blob' => "master:mailmap.txt");
    my $it = $r->log_mailmap;
    while (my $log = $it->next) {
      is($log->author_name, 'an2');
      is($log->author_email, 'a@example.org');
      is($log->committer_name, 'cn2');
      is($log->committer_email, 'c@example.org');
    }
  }

  $mailmap =~ s/^([ac]n)\S*/${1}3/gm;

  {
    my $file = catfile($r->work_tree, 'mailmap.txt');
    write_file($file, $mailmap);
    $r->run(add => $file);
    $r->run(commit => '-m' => "adds $file");
    $r->run(config => 'mailmap.file' => $file);
    my $it = $r->log_mailmap;
    while (my $log = $it->next) {
      is($log->author_name, 'an3');
      is($log->author_email, 'a@example.org');
      is($log->committer_name, 'cn3');
      is($log->committer_email, 'c@example.org');
    }
  }

  $r = undef;
}

done_testing();