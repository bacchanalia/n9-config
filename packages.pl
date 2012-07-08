#!/usr/bin/perl
use strict;
use warnings;

my $repoDir = 'repos';
my $debDir = 'debs-custom';
my $debDestPrefix = '/opt';

my @packagesToRemove = qw(
  wxapp apnews realgolf2011 gof2 nfsshift
  angrybirdsfreemagic
  ovi-music-store morpheus morpheus-guard

  mp-harmattan-005-pr
  facebook twitter twitter-qml
);

my $env = 'AEGIS_FIXED_ORIGIN=com.nokia.maemo';

my %pkgGroups = (
  '1' => [qw(
    bash vim rsync wget git openvpn
  )],
  '2' => [qw(
    perl bash-completion python python-apt
    mcetools bzip2 sqlite3
    x11-utils xresponse
    meecast
    xmimd
    imagemagick
    libterm-readkey-perl
    python-pyside.qtgui python-qmsystem python-pyside.qtdeclarative
    python-qtmobility.multimediakit
  )],
  '3' => [qw(
    linux-kernel-headers
    gcc make
  )],
  '4' => [qw(
    brujula
  )],
);

sub installPackages();
sub removePackages();
sub setupRepos();
sub installDebs();

sub main(@){
  my $arg = shift;
  $arg = 'all' if not defined $arg;
  if(@_ > 0 or $arg !~ /^(all|repos|packages|remove|debs)$/){
    die "Usage: $0 [all|repos|packages|remove|debs]\n";
  }
  if($arg =~ /^(all|repos)$/){
    if(setupRepos()){
      system 'n9', '-s', "$env apt-get update";
    }
  }
  installPackages() if $arg =~ /^(all|packages)$/;
  removePackages() if $arg =~ /^(all|remove)$/;
  installDebs() if $arg =~ /^(all|debs)$/;
}


sub getRepos(){
  #important to sort the files and not the lines
  my $cmd = 'ls /etc/apt/sources.list.d/*.list | sort | xargs cat';
  return `n9 -s '$cmd'`;
}

sub setupRepos(){
  my $before = getRepos();
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
  
  my $after = getRepos();
  return $before ne $after;
}

sub installPackages(){
  print "\n\n";
  for my $pkgGroup(sort keys %pkgGroups){
    my @packages = @{$pkgGroups{$pkgGroup}}; 
    print "Installing group[$pkgGroup]:\n----\n@packages\n----\n";
    system "n9", "-s", ''
      . "yes |"
      . " $env apt-get install"
      . " -y --allow-unauthenticated"
      . " @packages";
  }
}

sub getInstalledVersion($){
  my $pkg = shift;
  my $cmd = "n9 -s apt-cache show $pkg 2>&1";
  my $status = `$cmd`;
  if($status =~ /^Status: install ok installed$/m){
    if($status =~ /^Version: (.*)/m){
      return $1;
    }
  }
  return undef;
}

sub getArchiveVersion($){
  my $debArchive = shift;
  my $status = `dpkg --info $debArchive`;
  if($status =~ /^ Version: (.*)/m){
    return $1;
  }else{
    return undef;
  }
}

sub getArchivePackageName($){
  my $debArchive = shift;
  my $status = `dpkg --info $debArchive`;
  if($status =~ /^ Package: (.*)/m){
    return $1;
  }else{
    return undef;
  }
}

sub removePackages(){
  print "\n\nInstalling the deps for removed packages to unmarkauto\n";
  my %deps;
  for my $line(`n9 -s apt-cache depends @packagesToRemove`){
    if($line =~ /  Depends: (.*)/){
      $deps{$1} = 1;
    }
  }
  for my $pkg(@packagesToRemove){
    delete $deps{$pkg};
  }
  my $depInstallCmd = "$env apt-get install \\\n";
  for my $dep(keys %deps){
    $depInstallCmd .= "  $dep \\\n";
  }
  print $depInstallCmd;
  system 'n9', '-s', $depInstallCmd;

  print "\n\nChecking uninstalled packages\n";
  my $removeCmd = '';
  for my $pkg(@packagesToRemove){
    if(defined getInstalledVersion $pkg){
      $removeCmd .= "$env dpkg --purge $pkg\n";
    }else{
      print "Skipped already uninstalled package $pkg\n";
    }
  }
  print "\n\nRemoving bad packages\n";
  if($removeCmd ne ''){
    print $removeCmd;
    system 'n9', '-s', $removeCmd;
  }
}

sub isAlreadyInstalled($){
  my $debFile = shift;
  my $packageName = getArchivePackageName $debFile;
  my $archiveVersion = getArchiveVersion $debFile;
  my $installedVersion = getInstalledVersion $packageName;
  if(not defined $archiveVersion or not defined $installedVersion){
    return 0;
  }else{
    return $archiveVersion eq $installedVersion;
  }
}

sub installDebs(){
  my @debs = `cd $debDir; ls */*.deb`;
  chomp foreach @debs;
  
  print "\n\nSyncing $debDestPrefix/$debDir to $debDestPrefix on dest:\n";
  print "---\n@debs\n---\n";
  system "rsync $debDir root@`n9`:$debDestPrefix -av --progress --delete";

  print "\n\nChecking installed versions\n";
  my $cmd = '';
  for my $deb(@debs){
    my $localDebFile = "$debDir/$deb";
    my $remoteDebFile = "$debDestPrefix/$debDir/$deb\n";
    if(not isAlreadyInstalled($localDebFile)){
      $cmd .= "$env dpkg -i $remoteDebFile\n";
      $cmd .= "if [ \$? != 0 ]; then "
              . "$env apt-get -f install -y --allow-unauthenticated; "
              . "fi\n";
    }else{
      print "Skipping already installed $deb\n";
    }
  }
  
  print "\n\nInstalling debs\n";
  if($cmd ne ''){
    print $cmd;
    system 'n9', '-s', "set -x; $cmd";
  }
}

&main(@ARGV);
