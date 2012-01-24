#!/usr/bin/perl
use strict;
use warnings;

my $repoDir = 'repos';
my $debDir = 'packages';

my %pkgGroups = (
  '1hdev' => [qw(
    bash
  )],
  '2hrzrh' => [qw(
    n9tweak rsync vim git bash-completion
  )],
  '3meego' => [qw(
    python perl
  )],
  '4hdev' => [qw(
    kernel-source linux-kernel-headers
    gcc make libc6-dev libc-dev bzip2
  )],
);

sub installPackages();
sub setupRepos();
sub installDebs();

sub main(@){
  die "Usage: $0\n" if @_ > 0;
  setupRepos();
  system 'n9', '-s', 'apt-get', 'update';
  installPackages();
  installDebs();
}


sub setupRepos(){
  my $host = `n9`;
  chomp $host;

  my @repos = `ls $repoDir/*.list`;
  foreach my $repo(@repos){
    chomp $repo;
    print "copying $repo:\n";
    print "====\n";
    system 'cat', $repo;
    print "====\n\n";
  }

  system 'scp', @repos, "root\@$host:/etc/apt/sources.list.d/";
}

sub installPackages(){
  for my $pkgGroup(sort keys %pkgGroups){
    my @packages = @{$pkgGroups{$pkgGroup}}; 
    print "Installing $pkgGroup:\n----\n@packages----\n";
    my @cmd = ('n9', '-s', 'apt-get',
      'install', @packages,
      '-y', '--force-yes',
    );
    system @cmd;
  }
}

sub installDebs(){
  my @debs = `ls $debDir/*.deb`;
  my $dir = '/opt/manual-packages';
  print "\n\nCopying and installing these debs to $dir:\n";
  print "---\n@debs---\n";
  system "rsync packages/ root@`n9`:$dir -av --progress --delete";
  for my $deb(@debs){
    chomp $deb;
    system 'n9', '-s', 'dpkg', '-i', "$dir/$deb"; 
  }
}

&main(@ARGV);
