#!/usr/bin/perl
#
# $Id: migrate_passwd.pl,v 1.17 2005/03/05 03:15:55 lukeh Exp $
#
# Copyright (c) 1997-2003 Luke Howard.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#	notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#	notice, this list of conditions and the following disclaimer in the
#	documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#	must display the following acknowledgement:
#		This product includes software developed by Luke Howard.
# 4. The name of the other may not be used to endorse or promote products
#	derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE LUKE HOWARD ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL LUKE HOWARD BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
#
# Password migration tool. Migrates /etc/shadow as well, if it exists.
#
# Thanks to Peter Jacob Slot <peter@vision.auk.dk>.
#
# UTF8 support by Jonas Smedegaard <dr@jones.dk>.

require '/usr/share/migrationtools/migrate_common.ph';

$PROGRAM = "migrate_passwd.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);

&parse_args();
&read_shadow_file();
&open_files();

while(<INFILE>)
{
	chop;
	next if /^\s*$/;
	next if /^#/;
	next if /^\+/;

	local($user, $pwd, $uid, $gid, $gecos, $homedir, $shell) = split(/:/);

	next if (int($IGNORE_UID_BELOW) and int($uid) < int($IGNORE_UID_BELOW));
	next if (int($IGNORE_UID_ABOVE) and int($uid) > int($IGNORE_UID_ABOVE));
	next if (int($IGNORE_GID_BELOW) and int($gid) < int($IGNORE_GID_BELOW));
	next if (int($IGNORE_GID_ABOVE) and int($gid) > int($IGNORE_GID_ABOVE));

	if ($use_stdout) {
		&dump_user(STDOUT, $user, $pwd, $uid, $gid, $gecos, $homedir, $shell);
	} else {
		&dump_user(OUTFILE, $user, $pwd, $uid, $gid, $gecos, $homedir, $shell);
	}
}

sub dump_user
{
	local($HANDLE, $user, $pwd, $uid, $gid, $gecos, $homedir, $shell) = @_;
	local($name,$office,$wphone,$hphone)=split(/,/,$gecos);
	local($sn);	
	local($givenname);	
	local($cn);
	local(@tmp);

	if ($name) { $cn = $name; } else { $cn = $user; }

	$_ = $cn;
	@tmp = split(/\s+/);
	$sn = $tmp[$#tmp];
	pop(@tmp);
	$givenname=join(' ',@tmp);

	print $HANDLE "dn: uid=$user,$NAMINGCONTEXT\n";
	print $HANDLE "uid: $user\n";
	&print_utf8($HANDLE, "cn", $cn);

	if ($EXTENDED_SCHEMA) {
		if ($wphone) {
			&print_utf8($HANDLE, "telephoneNumber", $wphone);
		}
		if ($office) {
			&print_utf8($HANDLE, "roomNumber", $office);
		}
		if ($hphone) {
			&print_utf8($HANDLE, "homePhone", $hphone);
		}
		if ($givenname) {
			&print_utf8($HANDLE, "givenName", $givenname);
		}
		&print_utf8($HANDLE, "sn", $sn);
		if ($DEFAULT_MAIL_DOMAIN) {
			print $HANDLE "mail: $user\@$DEFAULT_MAIL_DOMAIN\n";
		}
		if ($DEFAULT_MAIL_HOST) {
			print $HANDLE "mailRoutingAddress: $user\@$DEFAULT_MAIL_HOST\n";
			print $HANDLE "mailHost: $DEFAULT_MAIL_HOST\n";
			print $HANDLE "objectClass: inetLocalMailRecipient\n";
		}
		print $HANDLE "objectClass: person\n";
		print $HANDLE "objectClass: organizationalPerson\n";
		print $HANDLE "objectClass: inetOrgPerson\n";
	} else {
		print $HANDLE "objectClass: account\n";
	}

	print $HANDLE "objectClass: posixAccount\n";
	print $HANDLE "objectClass: top\n";

	if ($DEFAULT_REALM) {
		print $HANDLE "objectClass: krbPrincipalAux\n";
	}

	if ($shadowUsers{$user} ne "") {
		&dump_shadow_attributes($HANDLE, split(/:/, $shadowUsers{$user}));
	} else {
		print $HANDLE "userPassword: {crypt}$pwd\n";
	}

	if ($DEFAULT_REALM) {
		print $HANDLE "krbPrincipalName: $user\@$DEFAULT_REALM\n";
	}

	if ($shell) {
		print $HANDLE "loginShell: $shell\n";
	}

	if ($uid ne "") {
		print $HANDLE "uidNumber: $uid\n";
	} else {
		print $HANDLE "uidNumber:\n";
	}

	if ($gid ne "") {
		print $HANDLE "gidNumber: $gid\n";
	} else {
		print $HANDLE "gidNumber:\n";
	}

	if ($homedir) {
		print $HANDLE "homeDirectory: $homedir\n";
	} else {
		print $HANDLE "homeDirectory:\n";
	}

	if ($gecos) {
		&print_ascii($HANDLE, "gecos", $gecos);
	}

	print $HANDLE "\n";
}

close(INFILE);
if (OUTFILE != STDOUT) { close(OUTFILE); }

sub read_shadow_file
{
	open(SHADOW, "/etc/shadow") || return;
	while(<SHADOW>) {
		chop;
		($shadowUser) = split(/:/, $_);
		$shadowUsers{$shadowUser} = $_;
	}
	close(SHADOW);
}

sub dump_shadow_attributes
{
	local($HANDLE, $user, $pwd, $lastchg, $min, $max, $warn, $inactive, $expire, $flag) = @_;

	print $HANDLE "objectClass: shadowAccount\n";
	if ($pwd) {
		print $HANDLE "userPassword: {crypt}$pwd\n";
	}
	if ($lastchg ne "") {
		print $HANDLE "shadowLastChange: $lastchg\n";
	}
	if ($min) {
		print $HANDLE "shadowMin: $min\n";
	}
	if ($max) {
		print $HANDLE "shadowMax: $max\n";
	}
	if ($warn) {
		print $HANDLE "shadowWarning: $warn\n";
	}
	if ($inactive) {
		print $HANDLE "shadowInactive: $inactive\n";
	}
	if ($expire) {
		print $HANDLE "shadowExpire: $expire\n";
	}
	if ($flag) {
		print $HANDLE "shadowFlag: $flag\n";
	}
}

sub print_utf8
{
	my($HANDLE, $attribute, $content) = @_;

	if (&validate_ascii($content)) {
		print $HANDLE "$attribute: $content\n";
	} elsif ($USE_UTF8) {
#		$content = &recode_custom_to_utf8($content);
		$content = &recode_latin1_to_utf8($content);
		if (&validate_utf8($content)) {
			$content = &encode_base64($content, "");
			print $HANDLE "$attribute\:: $content\n";
		} else {
			die "ERROR: Illegal character(s) in UTF-8 string: \"$content\"";
		}
	} else {
		&print_ascii($HANDLE, "$attribute", "$content");
	}
}

sub print_ascii
{
	my($HANDLE, $attribute, $content) = @_;

	if (&validate_utf8($content)) {
		$content = &recode_utf8_to_latin1($content);
	} else {
		$content = &recode_latin1_to_utf8($content);
		$content = &recode_utf8_to_latin1($content);
	}
	$content = &recode_custom_to_ascii($content);
	if (&validate_ascii($content)) {
		print $HANDLE "$attribute: $content\n";
	} else {
		my $badchars = $content;
		for ($badchars) {
			s/[\x20-\x7E]//g;
		}
		die "ERROR: Illegal character(s) \"$badchars\" in ASCII string: \"$content\"";
	}
}

sub recode_latin1_to_utf8
{
	my ($content) = @_;
	for ($content) {
		s/([\x80-\xFF])/chr(0xC0|ord($1)>>6).chr(0x80|ord($1)&0x3F)/eg;
	}
	return ($content)
}

sub recode_utf8_to_latin1
{
	my ($content) = @_;
	for ($content) {
		s/([\xC2\xC3])([\x80-\xBF])/chr(ord($1)<<6&0xC0|ord($2)&0x3F)/eg;
	}
	return ($content)
}

sub recode_custom_to_ascii
{
	my ($content) = @_;
	for ($content) {
		s/\xc0/A/g; # latin capital letter a with grave
		s/\xc1/A/g; # latin capital letter a with acute
		s/\xc2/A/g; # latin capital letter a with circumflex
		s/\xc3/A/g; # latin capital letter a with tilde
		s/\xc4/Ae/g; # latin capital letter a with diaeresis
		s/\xc5/Aa/g; # latin capital letter a with ring above
		s/\xc6/Ae/g; # latin capital letter ae
		s/\xc7/C/g; # latin capital letter c with cedilla
		s/\xc8/E/g; # latin capital letter e with grave
		s/\xc9/E/g; # latin capital letter e with acute
		s/\xca/E/g; # latin capital letter e with circumflex
		s/\xcb/Ee/g; # latin capital letter e with diaeresis
		s/\xcc/I/g; # latin capital letter i with grave
		s/\xcd/I/g; # latin capital letter i with acute
		s/\xce/I/g; # latin capital letter i with circumflex
		s/\xcf/Ie/g; # latin capital letter i with diaeresis
		s/\xd0/Dh/g; # latin capital letter eth (icelandic)
		s/\xd1/N/g; # latin capital letter n with tilde
		s/\xd2/O/g; # latin capital letter o with grave
		s/\xd3/O/g; # latin capital letter o with acute
		s/\xd4/O/g; # latin capital letter o with circumflex
		s/\xd5/O/g; # latin capital letter o with tilde
		s/\xd6/Oe/g; # latin capital letter o with diaeresis
		s/\xd8/Oe/g; # latin capital letter o with stroke
		s/\xd9/U/g; # latin capital letter u with grave
		s/\xda/U/g; # latin capital letter u with acute
		s/\xdb/U/g; # latin capital letter u with circumflex
		s/\xdc/Ue/g; # latin capital letter u with diaeresis
		s/\xdd/Y/g; # latin capital letter y with acute
		s/\xde/TH/g; # latin capital letter thorn (icelandic)
		s/\xdf/ss/g; # latin small letter sharp s (german)
		s/\xe0/a/g; # latin small letter a with grave
		s/\xe1/a/g; # latin small letter a with acute
		s/\xe2/a/g; # latin small letter a with circumflex
		s/\xe3/a/g; # latin small letter a with tilde
		s/\xe4/ae/g; # latin small letter a with diaeresis
		s/\xe5/aa/g; # latin small letter a with ring above
		s/\xe6/ae/g; # latin small letter ae
		s/\xe7/c/g; # latin small letter c with cedilla
		s/\xe8/e/g; # latin small letter e with grave
		s/\xe9/e/g; # latin small letter e with acute
		s/\xea/e/g; # latin small letter e with circumflex
		s/\xeb/ee/g; # latin small letter e with diaeresis
		s/\xec/i/g; # latin small letter i with grave
		s/\xed/i/g; # latin small letter i with acute
		s/\xee/i/g; # latin small letter i with circumflex
		s/\xef/ii/g; # latin small letter i with diaeresis
		s/\xf0/dh/g; # latin small letter eth (icelandic)
		s/\xf1/n/g; # latin small letter n with tilde
		s/\xf2/o/g; # latin small letter o with grave
		s/\xf3/o/g; # latin small letter o with acute
		s/\xf4/o/g; # latin small letter o with circumflex
		s/\xf5/o/g; # latin small letter o with tilde
		s/\xf6/oe/g; # latin small letter o with diaeresis
		s/\xf8/oe/g; # latin small letter o with stroke
		s/\xf9/u/g; # latin small letter u with grave
		s/\xfa/u/g; # latin small letter u with acute
		s/\xfb/u/g; # latin small letter u with circumflex
		s/\xfc/ue/g; # latin small letter u with diaeresis
		s/\xfd/y/g; # latin small letter y with acute
		s/\xfe/th/g; # latin small letter thorn (icelandic)
		s/\xff/ye/g; # latin small letter y with diaeresis
	}
	return ($content);
}

sub encode_base64
# Found in email by Baruzzi Giovanni <giovanni.baruzzi@allianz-leben.de> on openldap mailinglist

# Historically this module has been implemented as pure perl code.
# The XS implementation runs about 20 times faster, but the Perl
# code might be more portable, so it is still here.
{
	my $res = "";
	my $eol = $_[1];
	$eol = "\n" unless defined $eol;
	pos($_[0]) = 0; # ensure start at the beginning
	while ($_[0] =~ /(.{1,45})/gs) {
		$res .= substr(pack('u', $1), 1);
		chop($res);
	}
	$res =~ tr|` -_|AA-Za-z0-9+/|;               # `# help emacs
	# fix padding at the end
	my $padding = (3 - length($_[0]) % 3) % 3;
	$res =~ s/.{$padding}$/'=' x $padding/e if $padding;
	# break encoded string into lines of no more than 76 characters each
	if (length $eol) {
		$res =~ s/(.{1,76})/$1$eol/g;
	}
	$res;
}

sub validate_ascii
{
	my ($content) = @_;
	$content =~ /^[\x20-\x7E]*$/;
}

sub validate_utf8
{
	my ($content) = @_;
	if (&validate_ascii($content)) {
		return 1;
	}
	if ($] >= 5.8) {
		## No Perl support for UTF-8! ;-/
		return undef;
	}
	$content =~ /^[\x20-\x7E\x{0080}-\x{FFFF}]*$/;
