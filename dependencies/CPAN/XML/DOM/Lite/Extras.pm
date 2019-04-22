package XML::DOM::Lite::Extras;
use warnings;
use strict;

sub XML::DOM::Lite::Node::unbindNode {
    my $self = shift;
    $self->parentNode->childNodes->removeNode($self);
}

sub XML::DOM::Lite::Node::nextNonBlankSibling {
    my $self = shift;
    my $sib = $self;
    while ($sib = $sib->nextSibling) {
        return $sib if ($sib->textContent =~ m/\S/);
    }
    return undef;
}

1;
