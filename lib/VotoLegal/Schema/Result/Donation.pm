use utf8;
package VotoLegal::Schema::Result::Donation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VotoLegal::Schema::Result::Donation

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::TimeStamp>

=item * L<DBIx::Class::PassphraseColumn>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp", "PassphraseColumn");

=head1 TABLE: C<donation>

=cut

__PACKAGE__->table("donation");

=head1 ACCESSORS

=head2 id

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 candidate_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 email

  data_type: 'text'
  is_nullable: 0

=head2 cpf

  data_type: 'text'
  is_nullable: 0

=head2 phone

  data_type: 'text'
  is_nullable: 1

=head2 amount

  data_type: 'integer'
  is_nullable: 0

=head2 status

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "candidate_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "email",
  { data_type => "text", is_nullable => 0 },
  "cpf",
  { data_type => "text", is_nullable => 0 },
  "phone",
  { data_type => "text", is_nullable => 1 },
  "amount",
  { data_type => "integer", is_nullable => 0 },
  "status",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 candidate

Type: belongs_to

Related object: L<VotoLegal::Schema::Result::Candidate>

=cut

__PACKAGE__->belongs_to(
  "candidate",
  "VotoLegal::Schema::Result::Candidate",
  { id => "candidate_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 project_votes

Type: has_many

Related object: L<VotoLegal::Schema::Result::ProjectVote>

=cut

__PACKAGE__->has_many(
  "project_votes",
  "VotoLegal::Schema::Result::ProjectVote",
  { "foreign.donation_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-07-05 11:31:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:PCF9wB2CKnWmDLLXmJIvTw

use Digest::MD5 qw(md5_hex);
use VotoLegal::Payment::Cielo;

use Data::Printer;

has _cielo => (
    is      => "rw",
    isa     => "VotoLegal::Payment::Cielo",
    default => sub {
        my $self = shift;

        VotoLegal::Payment::Cielo->new(
            affiliation => $self->candidate->cielo_merchant_id,
            key         => $self->candidate->cielo_merchant_key,
            sandbox     => ($ENV{HARNESS_ACTIVE} || $0 =~ /forkprove/) ? 1 : 0,
        );
    },
);

has credit_card_name => (
    is  => "rw",
    isa => "Str",
);

has credit_card_validity => (
    is  => "rw",
    isa => "Str",
);

has credit_card_number => (
    is  => "rw",
    isa => "Str",
);

has credit_card_brand => (
    is  => "rw",
    isa => "Str",
);

has _card_token => (
    is  => "rw",
    isa => "Str",
);

has _transaction_id => (
    is  => "rw",
    isa => "Str",
);

sub tokenize {
    my ($self) = @_;

    defined $self->credit_card_name     or die "missing 'credit_card_name'.";
    defined $self->credit_card_validity or die "missing 'credit_card_validity'.";
    defined $self->credit_card_number   or die "missing 'credit_card_number'.";

    my $card_token = $self->_cielo->tokenize_credit_card(
        credit_card_data => {
            credit_card => {
                validity     => $self->credit_card_validity,
                name_on_card => $self->credit_card_name,
            },
            secret => {
                number => $self->credit_card_number,
            },
        },
    );

    if ($card_token) {
        $self->_card_token($card_token);

        $self->update({
            status => "tokenized",
        });

        return 1;
    }
    return 0;
}

sub authorize {
    my ($self) = @_;

    defined $self->_card_token       or die 'credit card not tokenized.';
    defined $self->credit_card_brand or die "missing 'credit_card_brand'.";

    my $res = $self->_cielo->do_authorization(
        token     => $self->_card_token,
        remote_id => substr(md5_hex($self->id), 0, 20),
        brand     => $self->credit_card_brand,
        amount    => $self->amount,
    );

    if ($res->{authorized}) {
        $self->_transaction_id($res->{transaction_id});

        $self->update({ status => "authorized" });

        return 1;
    }
    return 0;
}

sub capture {
    my ($self) = @_;

    defined $self->_transaction_id or die 'transaction not authorized';

    my $res = $self->_cielo->do_capture(
        transaction_id => $self->_transaction_id
    );

    if ($res->{captured}) {
        $self->update({ status => "captured" });
        return 1;
    }

    return 0;
}

__PACKAGE__->meta->make_immutable;
1;
