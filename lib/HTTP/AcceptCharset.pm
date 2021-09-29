package HTTP::AcceptCharset;

# ABSTRACT: Parse the HTTP header 'Accept-Charset'

our $VERSION = '0.04';

use Moo;
use List::Util qw(first);

has string => ( is => 'ro', required => 1 );
has values => ( is => 'ro', lazy => 1, default => \&_parse_string );

sub match {
    my ($self, @values_to_check) = @_;

    @values_to_check =
        map{ [ $_, lc $_ ] }
        grep{ defined $_ && length $_ }
        @values_to_check;

    return '' if !@values_to_check;

    my @charsets = @{ $self->values || [] };
    return $values_to_check[0][0] if !@charsets;

    CHARSET:
    for my $charset ( @charsets ) {
        return $values_to_check[0][0] if $charset eq '*';

        my $c = lc $charset;
        my $found = first { $_->[1] eq $c } @values_to_check;
        return $found->[0] if $found;
    }

    return '';
}

around BUILDARGS => sub {
    my ($orig, $class, @args) = @_;
 
    return { string => $args[0] }
        if @args == 1 && !ref $args[0];
 
    return $class->$orig(@args);
};

sub _parse_string {
    my ($self) = @_;

    my @charsets = split /\s*,\s*/, $self->string // '';
    my %weighted;

    for my $charset ( @charsets ) {
        my ($charset_name, $quality) = split /;/, $charset;

        my ($weight) = ($quality // 'q=1')  =~ m{\Aq=(.*)\z};
        push @{ $weighted{$weight} }, $charset_name;
    }

    my @charset_names = map{ @{ $weighted{$_} || [] } } sort { $b <=> $a }keys %weighted;

    return \@charset_names;
}

1;

=head1 SYNOPSIS

    use HTTP::AcceptCharset;
    
    my $header          = 'utf-8, iso-8859-1;q=0.5';
    my $charset_header  = HTTP::AcceptCharset->new( $header );
    
    # returns utf-8
    my $use_charset     = $charset_header->match( qw/iso-8859-1 utf-8/ );

=head1 ATTRIBUTES

=head2 string

The header string as passed to C<new>.

=head2 values

The given charset in the prioritized order.

    Header                    | Values
    --------------------------+----------------------------
    utf-8, iso-8859-1;q=0.5   | utf-8, iso-8859-1
    iso-8859-1;q=0.5, utf-8   | utf-8, iso-8859-1
    utf-8                     | utf-8
    utf-8, *                  | utf-8, *
    utf-8;q=0.2, utf-16;q=0.5 | utf-16, utf-8

=head1 METHODS

=head2 new

    my $header          = 'utf-8, iso-8859-1;q=0.5';
    my $charset_header  = HTTP::AcceptCharset->new( $header );

=head2 match

    # header: 'utf-8, iso-8859-1;q=0.5';
    my $charset = $charset_header->match('utf-8');               # utf-8
    my $charset = $charset_header->match('iso-8859-1');          # iso-8859-1
    my $charset = $charset_header->match('iso-8859-1', 'utf-8'); # utf-8
    my $charset = $charset_header->match();                      # empty string
    my $charset = $charset_header->match(undef);                 # empty string
    my $charset = $charset_header->match('utf-16');              # empty string

=for Pod::Coverage BUILDARGS
