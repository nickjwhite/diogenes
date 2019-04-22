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

# sub nextNonBlankSibling {
#     my $self = shift;
#     my $sib = $self;
#     while ($sib = $sib->nextSibling) {
#         #        print STDERR $sib;
#         unless (($sib->nodeType == TEXT_NODE or $sib->nodeType == CDATA_SECTION_NODE)
#             and $sib->nodeValue =~ m/^\s*$/) {
#             return $sib;
#         }
#     }
# }


1;
