#!/usr/bin/perl

#  Expr.pm - A perl parser or mathematicall expressions.
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

use strict;

=head1 NAME

  Math::Expr - Parses mathematical expressions

=head1 SYNOPSIS

  require Math::Expr;
  
  $p=new Math::Expr;
  $e=$p->Parse("a+4*b-d/log(s)+f(d,e)");

=head1 DESCRIPTION

  Parses mathematical expressions into a tree structure. The expressions
  may contain integers, real numbers, alphanumeric variable names, 
  alphanumeric function names and most other characters might be used 
  as operators. The operators can even be longer than one character! 
  The only limitation is that a variable or function name may not start 
  on a digit, and not all chars are accepted as operations. To be exact, 
  here is the grammatic (in perl regexp notation):

    <Expr>     = -?<Elem>(<OpChr><Elem>)*
    <Elem>     = <Number>|<Var>|<Function>|\(<Expr>\)
    <Number>   = <Integer>|<Float>
    <Integer>  = \d+
    <Float>    = \d*\.\d+
    <Var>      = [a-zA-Z][a-zA-Z0-9]*(:[a-zA-Z][a-zA-Z0-9]*)?
    <Function> = [a-zA-Z][a-zA-Z0-9]*\(<Expr>(,<Expr>)*\)
    <OpChr>    = [^a-zA-Z0-9\(\)\,\.\:]+

  If the - sign is present at the beginning of an <Expr> Then a neg()
	function is placed around it. That is to allow constructions like 
  "-a*b" or "b+3*(-7)".

  A variable consists of two parts separated by a ':'-char. The first 
  part is the variable name, and the second optional part is its type. 
  Default type is Real.

=head1 METHODS

=cut

package Math::Expr;
  
require Math::Expr::Opp;
require Math::Expr::Var;
require Math::Expr::Num;
require Math::Expr::VarSet;
require Math::Expr::OpperationDB;

=head2 $p = new  Math::Expr

This is the constructor, it creates an object which later can be used
to parse the strings.

=cut

sub new {
	my $class = shift;
	my $self = bless { }, $class;
	$self->SetOppDB(shift);
	$self->Priority({'^'=>50, '/'=>40, '*'=>30, '-'=>20, '+'=>10, '='=>0});
	$self->InitDB;
	$self;
}

=head2 $e=$p->Parse($str)

This will parse the string $str and return an expression tree, in the 
form of a Math::Expr::Opp object (or in simple cases only a 
Math::Expr::Var or Math::Expr::Num object).

=cut


sub Parse {
	my ($self, $str) = @_;

  $str=~ s/\s*//g;
  $self->{'Str'}=$str;

  $self->NextToken;
  my $e=$self->Expr;
  $e->SetPri($self->{'Pri'});
	$e;
}

=head2   $p->Priority({'^'=>50, '/'=>40, '*'=>30, '-'=>20, '+'=>10})

This will set the priority of ALL the operands (there is currently no 
way to change only one of them). The priority decides what should be 
constructed if several operands is listed without delimiters. Eg if 
a+b*c should be treated as (a+b)*c or a+(b*c). (Default is listed in 
header).

=cut

sub Priority {
	my ($self, $p) = @_;
	$self->{'Pri'}=$p;
}

=head2 $p->SetOppDB($db)

Sets the OpperationDB to be used to $db. See L<Math::Expr::OpperationDB> 
for more info. This will be passed down to all objects returned by the parser
aswell.

=cut

sub SetOppDB {
	my ($self, $oppdb) = @_;

	$self->{'oppdb'}=$oppdb;
}

sub InitDB {
	my $self = shift;
	my $a=$self->{'oppdb'}{'opps'};

	foreach (keys %{$a}) {
		if ($a->{$_}->{'simp'}) {
			$a->{$_}->{'simp'}=$self->Parse($a->{$_}->{'simp'});
		}
	}
}

sub NextToken {
	my $self = shift;

	if ($self->{'Str'} =~ s/^([a-zA-Z][a-zA-Z0-9]*)\(//) {
		$self->{'TType'}="Func";
	} 
	elsif ($self->{'Str'} =~ s/^([a-zA-Z][a-zA-Z0-9]*(:[a-zA-Z][a-zA-Z0-9]*)?)//) {
		$self->{'TType'}="Var";
	}
	elsif ($self->{'Str'} =~ s/^(\d*\.\d+|\d+)//) {
		$self->{'TType'}="Num";
	}
	elsif ($self->{'Str'}=~ s/^([^a-zA-Z0-9\(\)\,\.\:]+)//) {
		$self->{'TType'}="OpChr";
	}
	elsif ($self->{'Str'}=~ s/^([\(\)\,])//){
		$self->{'TType'}="Chr";
	}
	else {
    if ($self->{'Str'} ne "") {$self->Bad}
		return 0;
	}
	$self->{'Token'}=$1;
  return 1;
}

sub Expr {
	my $self = shift;
  my $e;
	my $n;

	if ($self->{'Token'} eq '-') {
		$e= new Math::Expr::Opp('neg',$self->{'oppdb'});
		$self->NextToken;
		$e->SetOpp(0,$self->Elem);
	} else {
		$e=$self->Elem;
	}

  while ($self->{'TType'} eq 'OpChr'){
	  $n= new Math::Expr::Opp($self->{'Token'},$self->{'oppdb'});

		if ($e->{'Type'} eq 'Opp' &&
				defined $self->{'Pri'}{$e->{'Val'}} && 				
				defined $self->{'Pri'}{$n->{'Val'}} &&
				$self->{'Pri'}{$e->{'Val'}} < $self->{'Pri'}{$n->{'Val'}} &&
				$e->Breakable
			 ) {
			$n->SetOpp(0,$e->Opp(1));
			$self->NextToken;
			$n->SetOpp(1,$self->Elem);
			$n->Breakable(1);
			$n=$self->FixPri($n);
			$e->SetOpp(1,$n);
		} else {
			$n->SetOpp(0,$e);
			$self->NextToken;
			$n->SetOpp(1,$self->Elem);
			$n->Breakable(1);
			$e=$n;
		}
  } 
	$e->Breakable(0);
	return $e;
}

sub FixPri {
	my ($self, $n)=@_;
	my  $a=$n->Opp(0);
	my  $t;

	if ($a->{'Type'} eq 'Opp' &&
			defined $self->{'Pri'}{$n->{'Val'}} &&
			defined $self->{'Pri'}{$a->{'Val'}} &&
			$self->{'Pri'}{$a->{'Val'}} < $self->{'Pri'}{$n->{'Val'}} &&
			$a->Breakable
		 ) {
		$n->SetOpp(0,$a->Opp(1));
		$n=$self->FixPri($n);
		$a->SetOpp(1,$n);
		$a;
	} else {
		$n;
	}
}

sub Elem {
	my $self=shift;

	if ($self->{'TType'} eq "Var") {
		my $n = new Math::Expr::Var($self->{'Token'});
		$self->NextToken;
		return $n;
	}
	elsif ($self->{'TType'} eq "Num") {
		my $n = new Math::Expr::Num($self->{'Token'});
		$self->NextToken;
		return $n;
	}
	elsif ($self->{'TType'} eq "Var") {
		my $n = new Math::Expr::Var($self->{'Token'});
		$self->NextToken;
		return $n;
	}
	elsif ($self->{'Token'} eq "(") {
		$self->NextToken;
		my $n= $self->Expr;
		if ($self->{'Token'} ne ")") {
			$self->Bad;
		}
		$self->NextToken;
		return $n;
	}
	elsif ($self->{'TType'} eq "Func") {
		my $n=new Math::Expr::Opp($self->{'Token'},$self->{'oppdb'});
		my $o=0;
		do {
			$self->NextToken;
			$n->SetOpp($o, $self->Expr);
			$o++;
		}		while ($self->{'Token'} eq ",");
		if ($self->{'Token'} ne ")") {
			$self->Bad;
		}
		$self->NextToken;
		return $n
	} else {
		$self->Bad;
	}
}

sub Bad {
	my $self = shift;
  
  warn "Bad str: " . $self->{'Str'} . "\n";
}

=head1 BUGS

  The parses does not handle bad strings in a decent way. If you try 
  to parse a string that does not follow the specification above, all 
  strange things might happen...

=head1 AUTHOR

  Hakan Ardo <hakan@debian.org>

=head1 SEE ALSO

L<Math::Expr::Opp>

=cut
