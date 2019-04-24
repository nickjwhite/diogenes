package XML::DOM::Lite::Extras;
use warnings;
use strict;

sub XML::DOM::Lite::Node::unbindNode {
    my $self = shift;
    $self->parentNode->childNodes->removeNode($self);
}

sub XML::DOM::Lite::Node::nextNonBlankSibling {
    my $self = shift;
    my $sib = $self->nextSibling;
    while ($sib) {
        return $sib if ($sib->textContent =~ m/\S/);
        $sib = $sib->nextSibling;
    }
    return undef;
}

1;
