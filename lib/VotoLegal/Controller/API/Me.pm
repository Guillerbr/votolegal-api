package VotoLegal::Controller::API::Me;
use Moose;
use namespace::autoclean;

BEGIN { extends 'CatalystX::Eta::Controller::REST' }

=head1 NAME

VotoLegal::Controller::API::Candidate::Me - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub base : Chained('/api/logged') : PathPart('me') : CaptureArgs(0) {
    my ($self, $c) = @_;

    if (!$c->check_user_roles(qw(user))) {
        $self->status_forbidden($c, message => "access denied");
        $c->detach();
    }

    $c->stash->{collection} = $c->user->candidates;
}

sub me : Chained('base') : PathPart('') : ActionClass('REST') { }

sub me_GET {
    my ($self, $c) = @_;

    my $candidate = $c->stash->{collection}->search(
        {},
        {
            join         => 'party',
            '+select'    => ['party.name'],
            '+as'        => ['party_name'],
            result_class => 'DBIx::Class::ResultClass::HashRefInflator'
        }
    )->single;

    return $self->status_ok($c, entity => {
        candidate => $candidate,
    });
}

sub me_PUT {
    my ($self, $c) = @_;

    my $candidate = $c->stash->{collection}->single->execute($c, for => 'update', with => $c->req->params);

    return $self->status_accepted($c, entity => { id => $candidate->id });
}

=encoding utf8

=head1 AUTHOR

Junior Moraes,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;