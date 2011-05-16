package Fetch::Image;
use strict;
use warnings;

use LWPx::ParanoidAgent;
use Data::Validate::Image;
use Data::Validate::URI qw/is_web_uri/;
use File::Temp;
use Exception::Simple;

our $VERSION = '0.001';
$VERSION = eval $VERSION;

sub new{
    my ( $invocant, $config ) = @_;

    my $class = ref( $invocant ) || $invocant;
    my $self = {};
    bless( $self, $class );
    
    $self->{'image_validator'} = Data::Validate::Image->new;

    $self->{'config'} = $config;

    # setup some defaults
    if ( !defined($self->{'config'}->{'max_filesize'}) ){
        $self->{'config'}->{'max_filesize'} = 524_288;
    }

    # default allowed image types if none defined
    if ( !defined($self->{'config'}->{'allowed_types'}) ){
        $self->{'config'}->{'allowed_types'} = {
            'image/png' => 1,
            'image/jpg' => 1,
            'image/jpeg' => 1,
            'image/pjpeg' => 1,
            'image/bmp' => 1,
            'image/gif' => 1,
        };
    }

    return $self;
}

sub fetch{
    my ( $self, $url ) = @_;

    if ( !defined( $url ) ){
        Exception::Simple->throw("no url");
    } elsif ( !defined( is_web_uri( $url ) ) ){
        Exception::Simple->throw("invalid url");
    }

    my $ua = $self->_setup_ua( $url );

    my $head = $self->_head( $ua, $url );
    return $self->_save( $ua, $url )
        || Exception::Simple->throw("generic error");
}

#sets up the LWPx::ParanoidAgent
sub _setup_ua{
    my ( $self, $url ) = @_;

    my $ua = LWPx::ParanoidAgent->new;

    if ( defined( $self->{'config'}->{'user_agent'} ) ){
        $ua->agent( $self->{'config'}->{'user_agent'} );
    }

    if ( defined( $self->{'config'}->{'timeout'} ) ){
        $ua->timeout( $self->{'config'}->{'timeout'} );
    }
    $ua->cookie_jar( {} ); #don't care for cookies

    $ua->default_header( 'Referer' => $url ); #naughty, maybe, but will get around 99% of anti-leach protection :D

    return $ua;
}

# returns a HTTP::Response for a HTTP HEAD request
sub _head{
    my ( $self, $ua, $url ) = @_;

    my $head = $ua->head( $url );

    $head->is_error && Exception::Simple->throw("transfer error");

    exists( $self->{'config'}->{'allowed_types'}->{ $head->header('content-type') } ) 
        || Exception::Simple->throw("invalid content-type");

    if (
        $head->header('content-length')
        && ( $head->header('content-length') > $self->{'config'}->{'max_filesize'} ) 
    ){
    #file too big
        Exception::Simple->throw("filesize exceeded");
    }

    return $head;
}

# returns a File::Temp copy of the requested url
sub _save{
    my ( $self, $ua, $url ) = @_;

    my $response = $ua->get( $url ) 
        || Exception::Simple->throw("download Failed");

    my $temp_file = File::Temp->new 
        || Exception::Simple->throw("temp file save failed");
    $temp_file->print( $response->content );
    $temp_file->close;

    my $image_info = $self->{'image_validator'}->validate($temp_file->filename);

    if ( !$image_info ){
        $temp_file->DESTROY; 
        Exception::Simple->throw("not an image");
    };

    $image_info->{'temp_file'} = $temp_file;
    return $image_info;
}

1;
