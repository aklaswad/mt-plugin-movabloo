package Movabloo;
use strict;
use warnings;
use Crypt::OpenSSL::RSA;
use MIME::Base64;

sub install {
    my $app = shift;
    my $blog_id = $app->param('blog_id') or die "Blog ID is required";
    my $fmgr = MT::FileMgr->new('Local');

    require File::Temp;
    my $tmproot = File::Temp::tempdir(
        DIR => MT->config('TempDir'),
        CLEANUP => 1,
    );
    my $tmpdir = File::Spec->catdir( $tmproot, 'movabloo' );
    $fmgr->mkpath($tmpdir);

    my $arctype = 'zip';
    require MT::Util::Archive;
    my $arcfile = File::Temp::tempnam( $tmproot, 'movabloo.zip' );
    my $arc = MT::Util::Archive->new( $arctype, $arcfile )
        or die "Can't load archiver : " . MT::Util::Archive->errstr;

    my $contents = contents();
    for my $filename ( keys %$contents ) {
        my $path = File::Spec->catfile( $tmpdir, $filename );
        my $content = $contents->{$filename};
        $content = $content->() if 'CODE' eq ref $content;
        $fmgr->put_data( $content, $path );
        $arc->add_file($tmpdir, $filename);
    }
    $arc->close;

    my $zip = $fmgr->get_data($arcfile, 'upload');
    my $rsa = Crypt::OpenSSL::RSA->generate_key(1024);
    my $crx = pack_crx( $rsa, $zip );
    $app->{no_print_body} = 1;

#    $app->set_header(
#        "Content-Disposition" => "attachment; filename=aaa.zip" );
#    $app->send_http_header( 'application/zip' );
#    $app->print( $zip );

    $app->send_http_header( 'application/x-chrome-extension' );
    $app->print( $crx );
    return;
}

sub pack_crx {
    my ( $rsa, $zip ) = @_;
    $rsa->use_sha1_hash;
    my $signature = $rsa->sign( $zip );
    #my $v = $rsa->verify($zip, $signature);
    my $public = $rsa->get_public_key_x509_string;
    $public =~ s/-----BEGIN PUBLIC KEY-----\n//;
    $public =~ s/-----END PUBLIC KEY-----\n//;
    $public =~ s/\n//g;

    $public = decode_base64( $public );
    my $sig_len = length $signature;
    my $pub_len = length $public;
    my $header = pack 'I*', 2, $pub_len, $sig_len ;
    return 'Cr24' . $header . $public . $signature . $zip;
}

sub contents {
    my $app = MT->app;
    my $plugin = MT->component('Movabloo');
    my $extjs = File::Spec->catdir( $plugin->path, 'extjs');
    my $fmgr = MT::FileMgr->new('Local');
    my $read = sub {
        my $file = File::Spec->catfile($extjs, shift);
        return $fmgr->get_data($file);
    };
    my $base = $app->base;
    my $endpoint = $app->base . $app->app_path . $app->config->atomScript;
    my $blog_id = $app->param('blog_id');
    my $username = $app->user->name;
    my $password = $app->user->api_password;
    return {
        'jquery-1.4.4.min.js' => sub { $read->('jquery-1.4.4.min.js') },
        'base64.js' => sub { $read->('base64.js') },
        'sha1.js' => sub { $read->('sha1.js') },
        'atompub.js' => sub { $read->('atompub.js') },
        'manifest.json' => <<"TEXT",
{
    "name": "Movabloo",
    "version": "0.3",
    "background_page": "background.html",
    "permissions": [ "tabs", "contextMenus", "http://*/" ]
}
TEXT

        'background.html' => <<"TEXT",
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<title>atom client</title>


<script type="text/javascript" src="jquery-1.4.4.min.js"></script>
<script type="text/javascript" src="base64.js"></script>
<script type="text/javascript" src="sha1.js"></script>
<script type="text/javascript" src="atompub.js"></script>


<script type="text/javascript">
jQuery( function () {

var username = "$username";
var password = "$password";
var endpoint = "$endpoint";

function fromContext(info, tab) {
  if ( info.mediaType == 'image' ) {
    postAsset({
        endpoint: '$endpoint/1.0/blog_id=$blog_id/svc=upload',
        username: username,
        password: password,
        imageurl: info.srcUrl,
    });
  }
  else if ( info.selectionText ) {
     postEntry({
        endpoint: '$endpoint/1.0/blog_id=$blog_id/svc=entry',
        username: username,
        password: password,
        title: 'Quote',
        body: '<blockquote>' + info.selectionText + '<a href="' + info.pageUrl + '">' + tab.title + '</a></blockquote>',
      });
      //alert( 'Quote: ' + info.selectionText );
  }
}


chrome.contextMenus.create({
    title: "Movabloo",
    contexts: [ 'selection', 'image' ],
    onclick: fromContext

});




});
</script>
</head>
<body>
<input type="button" id="post-entry" value="post" />
<input type="button" id="post-asset" value="asset" />
</body>
</html>




TEXT
    };
}

1;
