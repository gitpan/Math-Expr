#!/usr/bin/perl

#  MatchSet.pm - A perl representation of matches in algebraic expretions
#  (c) Copyright 1998 Hakan Ardo <hakan@debian.org>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=head1 NAME

  Math::Expr::MatchSet - Represents matches in algebraic expretions

=head1 SYNOPSIS

  require Math::Expr::MatchSet;
  $s=new Math::Expr::MatchSet;
  $s->Set($pos,$match);
  $s->Get($pos);

=head1 DESCRIPTION

  Two expretion can be matched in several ways, therefor we need to be 
  able to represent a set of matches keyed by the matchposition (the 
  subexpretion, where the match where found).

=head1 METHODS

=cut

package Math::Expr::MatchSet;
use strict;

=head2 $s=new Math::Expr::MatchSet

  Create a new MatchSet object.

=cut

sub new {bless {}, shift}

=head2 $s->Set($pos, $match)

  Sets the match at $pos to $match.

=cut

sub Set {shift->Add(@_)}

=head2 $s->Add($pos, $match)

  Synonyme to Set.

=cut

sub Add {
  my ($self, $pos, $vars) = @_;

	$self->{'Matches'}{$pos}=$vars;
}

=head2 $s->Insert($mset)

  Inserts all mathes in the MatchSet £mset intho $s.

=cut

sub Insert {
	my ($self, $mset) = @_;
	
	foreach (keys %{$mset->{'Matches'}}) {
		$self->{'Matches'}{$_}=$mset->{'Matches'}{$_}
	}
}

=head2 $s->tostr

  Generates a string representation of the MatchSet, used for debugging.

=cut

sub tostr {
	my $self = shift;
	my $str="";


	foreach (keys %{$self->{'Matches'}}) {
		$str .= $_ . ":\n" . $self->{'Matches'}{$_}->tostr . "\n\n";
	}

	$str;
}

=head2 $s->Get($pos)

  Returns the Match at possition $pos.

=cut

sub Get {
	my ($self, $var) = @_;

	$self->{'Matches'}{$var};
}

=head2 $s->Keys

  Returns the positions at which there excists a match.

=cut

sub Keys {
	my ($self) = @_;
	
	keys %{$self->{'Matches'}};
}

1;
