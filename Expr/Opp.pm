#!/usr/bin/perl 

#  Opp.pm - A perl representation mathematicall expressions.
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

  Math::Expr::Opp - Represents one operation in the parsed expression 
                    tree

=head1 SYNOPSIS

  require Math::Expr::Opp;
  require Math::Expr::Var;
  require Math::Expr::Num;
  
  # To represent the expression "x+7":
  $n=new Math::Expr::Opp("+");
  $n->SetOpp(0,new Math::Expr::Var("x"));
  $n->SetOpp(1,new Math::Expr::Num(7));
  print $n->tostr . "\n";

=head1 DESCRIPTION

  Used by the Math::Expr to represent algebraic expressions. This class 
  represents one operation or function with a set of operands, which 
  in turn can be other Math::Expr::Opp objects. And in that way we are 
  able to represent entire expression.

  Operations like a+b and functions like sin(a) or f(a,b) are all 
  represented by this kind of objects with "+", "sin" and "f" as the
  operation- or function names and Math::Expr::Var(a) and 
  Math::Expr::Var(b) as operands (only a in the sin example).

=head1 METHODS

=cut

package Math::Expr::Opp;
require Math::Expr::MatchSet;
use strict;

=head2 $e=new  Math::Expr::Opp($name,$db)

  Creates a new operation object with the operation- or function-name 
  $name. Using the operations defined in $db. See 
  L<Math::Expr::OpperationDB> for more info.

=cut

sub new {
	my($class, $val, $db) = @_;
	my $self = bless { }, $class;

	$self->{'Type'}="Opp";
	$self->{'Val'}=$val;
	$self->{'oppdb'}=$db;
	$self->Breakable(0);

	$self;

}

=head2 $e->SetOpp($i, $v)

  Sets operand number $i to $v.

=cut

sub SetOpp {
	my ($self, $i, $val) = @_;

	$self->{'Opps'}[$i]=$val;
}

=head2 $e->Opp($i)

  Returns operand to number $i.

=cut

sub Opp {
	my ($self, $i) = @_;

	$self->{'Opps'}[$i];
}

=head2 $e->tostr

  Returns a string representation of the entire expression to be 
  used for debugging.

=cut

sub tostr {
	my $self = shift;
	my $str=$self->{'Val'}."(";
	my $i;

  for ($i=0; $i<=$#{$self->{'Opps'}}; $i++) {
    if (ref $self->{'Opps'}[$i]) {
			$str .= $self->{'Opps'}[$i]->tostr;
		} else {
			$str .= "?";
		}
    if ($i+1<=$#{$self->{'Opps'}}) {
      $str .= ",";
		}
	}
  "$str)";
}

=head2 $e->strtype

  Returns a string representation of this expressions entire type, 
  without simplifying it. In the same notation as the tostr method.

=cut

sub strtype {
	my $self = shift;
	my $str=$self->{'Val'}."(";
	my $i;

  for ($i=0; $i<=$#{$self->{'Opps'}}; $i++) {
    $str .= $self->{'Opps'}[$i]->strtype;
    if ($i+1<=$#{$self->{'Opps'}}) {
      $str .= ",";
		}
	}
  "$str)";
}

=head2 $n->Simplify

  Simplifys the expression to some normal from.

=cut

sub Simplify {
  my ($self)=@_;
	my $i;
	my $op;

  for ($i=0; $i<=$#{$self->{'Opps'}}; $i++) {
    $self->{'Opps'}[$i]->Simplify;
  }

	$op=$self->{'oppdb'}->Find($self->DBType);

	# (a+b)+c => a+b+c
  if ($op->{'ass'}) {
		my @nopp;
    for ($i=0; $i<=$#{$self->{'Opps'}}; $i++) {
      if ($self->{'Val'} eq $self->{'Opps'}[$i]{'Val'}) {
        foreach (@{$self->{'Opps'}[$i]{'Opps'}}) {
          push(@nopp, $_);
        }
      } else {
        push (@nopp, $self->{'Opps'}[$i]);
      }
    }
    $self->{'Opps'}=\@nopp;
  }

	# a+c+b => a+b+c
  if ($op->{'kom'}) {
		my @nopp = sort {$a->tostr cmp $b->tostr} @{$self->{'Opps'}};
		$self->{'Opps'}=\@nopp;
	}

}

=head2 $n->BaseType

  Returns a string type of this expression simplifyed as much as 
  possible.

=cut

sub BaseType {
  my ($self)=@_;
	my $op;
	my $str=$self->DBType;

	$op= $self->{'oppdb'}->Find($str);
	if ($op) {$str=$op->{'out'}}

	$str;
}

sub DBType {
  my ($self)=@_;
	my $str=$self->{'Val'}."(";
	my $i;

  for ($i=0; $i<=$#{$self->{'Opps'}}; $i++) {
    $str .= $self->{'Opps'}[$i]->BaseType;
    if ($i+1<=$#{$self->{'Opps'}}) {
      $str .= ",";
		}
	}
  "$str)";
}

=head2 $n->SubMatch($rules,$match)

  Tries to match $rules to this expretions and adds the substitutions 
  needed to $match.Returns 1 if the match excists and the substitutions 
  needed can coexcist with those already in $match otherwise 0.

=cut

sub SubMatch {
  my ($self, $rule, $match) = @_;
	if ($rule->{'Type'} eq 'Var' && 
			$rule->BaseType eq $self->BaseType
		 ) {
		return $match->Set($rule->{'Val'},$self);
  }
  elsif ($rule->{'Type'} eq 'Opp' &&
				 $rule->{'Val'} eq $self->{'Val'} &&
				 $#{$self->{'Opps'}} eq $#{$rule->{'Opps'}}
				) {
		my $ok=1;
		my $i;

		for ($i=0; $i<=$#{$self->{'Opps'}}; $i++) {
			if (!$self->{'Opps'}[$i]->SubMatch($rule->{'Opps'}[$i],$match)) {
				$ok=0;
				last;
			}
		}
		return $ok;
	} else {
		return 0;
	}
}

=head2 $n->Match($rules)

  Tries to match $rules to this expretions and to all its subexpretions. 
  Returns a MatchSet object specifying where the matches ocored and what 
  substitutions they represent.

=cut

sub Match {
  my ($self, $rule, $pos) = @_;
	my $match=new Math::Expr::VarSet;
	my $i;
	my $op=$self->{'oppdb'}->Find($self->DBType);
	my $mset = new Math::Expr::MatchSet;

	if (!defined $pos) {$pos="";}

	if ($self->SubMatch($rule, $match)) {
		$mset->Add($pos,$match);
	}

	if ($pos ne "") {$pos .=","}
	for ($i=0; $i<=$#{$self->{'Opps'}}; $i++) {
		$mset->Insert($self->{'Opps'}[$i]->Match($rule, "$pos$i"));
	}

	# Can only handle binary opps for now
#	my ($j,$k);
#	if ($op->{'ass'} && $#{$rule->{'Opps'}} == 1 && 
#			$rule->{'Val'} eq $self->{'Val'}) {
#		for ($i=0; $i<=$#{$self->{'Opps'}}; $i++) {
#			for ($j=$i; $j>=0; $j--) {
#				for ($k=$i+1; $k<=$#{$self->{'Opps'}}; $k++) {
#					my $match = new Math::Expr::MatchSet;
#					print "$j $i $k\n";
#					if ($self->SubOpp($i,$j)->SubMatch($rule->{'Opps'}[0],$match) &&
#							$self->SubOpp($i+1,$k)->SubMatch($rule->{'Opps'}[1],$match)) {
#						# FIXME: Has to remove more objs than $i!!
#						# FIXME: MIght get duplicates...
#						print "hej\n";
#						$mset->Add("$pos$i", $match);
#					}
#				}
#			}
#		}
#	}

	$mset;
}

sub SubOpp {
  my ($self, $a,$b) = @_;
  my $i;
  my $o= new Math::Expr::Opp($self->{'Val'},$self->{'oppdb'});

  if ($a==$b) {return $self->{'Opps'}[$a]}

  for ($i=$a; $i<=$b; $i++) {
    $o->SetOpp($i-$a,$self->{'Opps'}[$i]);
  }
  $o;
}

=head2 $n->Subs($vars)

  Substitues all variables in the expretion with there vaules in $vars.

=cut

sub Subs {
	my ($self, $vars) = @_;
	my $i;
	my $n = new Math::Expr::Opp($self->{'Val'},$self->{'db'});

  for ($i=0; $i<=$#{$self->{'Opps'}}; $i++) {
		$n->{'Opps'}[$i]=$self->{'Opps'}[$i]->Subs($vars);
	}
	$n;
}

=head2 $n->Copy

Returns a copy of this object.

=cut

sub Copy {
	my $self = shift;
	my $n = new Math::Expr::Opp($self->{'Val'}, $self->{'oppdb'});
	my $i;

  for ($i=0; $i<=$#{$self->{'Opps'}}; $i++) {
		$n->{'Opps'}[$i]=$self->{'Opps'}[$i]->Copy;
	}
	$n;
}

=head2 $n->Breakable

  Used by the parser to indikate if this object was created using 
  parantesis or if he should break it up to preserve the rules of order 
  between the diffrent opperations.

=cut

sub Breakable {
  my $self=shift;
  my $val=shift;

  if (defined $val) {$self->{'Breakable'}=$val}
  $self->{'Breakable'}
}

=head2 $n->Find($pos)

  Returns an object pointer to the subexpression represented by the 
  string $pos.

=cut

sub Find {
  my ($self, $pos) = @_;

  if ($pos =~ s/^(\d+),?//) {
    return $self->{'Opps'}[$1]->Find($pos);
  } else {
    return $self;
  }
}

=head2 $n->Set($pos, $val)

  Replaces the subexpression at position $pos with $val.

=cut

sub Set {
  my ($self, $pos, $val) = @_;

  if ($pos =~ s/^(\d+),//) {
    $self->{'Opps'}[$1]->Set($pos,$val);
    return $self;
  } else {
    if ($pos eq "") {
      return $val;
    } else {
      $self->{'Opps'}[$pos]=$val;
      return $self;
    }
  }
}

=head1 AUTHOR

  Hakan Ardo <hakan@debian.org>

=head1 SEE ALSO

  L<Math::Expr>

=cut

1;
