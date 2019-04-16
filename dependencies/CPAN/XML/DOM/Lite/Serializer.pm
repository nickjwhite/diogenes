package XML::DOM::Lite::Serializer;
use warnings;
use strict;

use XML::DOM::Lite::Constants qw(:all);

sub new {
    my ($class, %options) = @_;
    my $self = bless { }, $class;

    $self->{_newline} = "\n";
    $self->{_space} = " ";
    if (defined($options{'indent'})) {
        my $mode = $options{'indent'};
        if (index($mode, 'none') >= 0) {
            $self->{_newline} = "";
            $self->{_space} = "";
        }
    }
    return $self;
}

sub serializeToString {
    my ($self, $node) = @_;
    unless (ref $self) {
        $self = __PACKAGE__->new;
    }
    my $out = "";

    if ($node->nodeType == DOCUMENT_NODE) {
        foreach my $n (@{$node->childNodes}) {
            $out .= $self->serializeToString($n);
        }
    }

    $self->{_indent_level} = 0 unless defined $self->{_indent_level};

    if ($node->nodeType == ELEMENT_NODE) {
        $out .= $self->{_newline}.$self->_mkIndent()."<".$node->tagName;
        foreach my $att (@{$node->attributes}) {
            $out .= " $att->{nodeName}=\"".$att->{nodeValue}."\"";
        }
        if ($node->childNodes->length) {
            $out .= ">";
            $self->{_indent_level}++;
            foreach my $n (@{$node->childNodes}) {
                $out .= $self->serializeToString($n);
            }
            $self->{_indent_level}--;
            $out .= $self->{_newline}.$self->_mkIndent()."</".$node->tagName.">";
        } else {
            $out .= " />";
        }
    }
    elsif ($node->nodeType == TEXT_NODE) {
        $out .= $self->{_newline}.$self->_mkIndent().$node->nodeValue;
    }
    elsif ($node->nodeType == PROCESSING_INSTRUCTION_NODE) {
        $out .= "<?".$node->nodeValue."?>";
    }
    return $out;
}

sub _mkIndent {
    my ($self) = @_;
    return ($self->{_space} x (2 * $self->{_indent_level}));
}
1;
