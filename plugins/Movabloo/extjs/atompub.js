function makeWSSE ( username, password ) {
    var t = 1;
    var token = '';
    var date = (new Date).toISOString();
    var nonce = hex_sha1( 'nonce' + (new Date) + Math.random().toString );
    var digest = b64_sha1( nonce + date + password );
    var values = {
        Username: username,
        PasswordDigest: digest,
        Nonce: window.btoa(nonce),
        Created: date,
    };
    var wsse = '';
    for ( var key in values ) {
        wsse += key + '="' + values[key] + '", ';
    }
    return wsse;
}

function postEntry (opts) {

    var endpoint = 'http://localhost/~asawada/cgi-bin/movabletype/mt-atom.cgi/1.0/blog_id=2/svc=entry';

    var xml = '<?xml version="1.0" encoding="utf-8"?>';
    xml += '<entry xmlns="http://www.w3c.org/2005/Atom">';
    xml += '<title>' + Base64.btou(opts.title) + '</title>';
    xml += '<content type="xhtml">' + Base64.btou(opts.body) + '</content>';
    xml += '</entry>';

    $.ajax({
        url: opts.endpoint,
        type: 'POST',
        data: xml,
        contentType: 'application/xml+atom',
        beforeSend: function ( xhr ) {
            xhr.setRequestHeader('X-WSSE', 'UsernameToken ' + makeWSSE(opts.username, opts.password) );
        },
        //success: function ( data, type ) {
        //    console.log( data );
        //    console.log( type );
        //},
        error: function ( xhr, text, thrown ){
            alert('Failed to post entry');
        },
    });
}

function postAsset (opts) {
    var image;
    var contentType;
    $.ajax({
        url: opts.imageurl,
        async: false,
        beforeSend: function ( xhr, setting ) {
          xhr.overrideMimeType('text/plain; charset=x-user-defined');
        },
        success: function ( data, type ) {
            image = data;
        },
        error: function () {
            alert('Failed to fetch image file');
        },
        complete: function ( xhr ) {
            contentType = xhr.getResponseHeader('Content-Type');
        }
    });
    var bytes = [];

//    for (i = 0; i < image.length; i++)
//      bytes[i] = image.charCodeAt(i) & 0xff;
//    image = String.fromCharCode.apply(String, bytes)

    var fixedImage = '';
    console.log('hey');
    for (i = 0; i < image.length; i++)
      fixedImage += String.fromCharCode(image.charCodeAt(i) & 0xff);
    console.log('OK');
    var filename = opts.imageurl;
    title = filename.replace(/.*\//, '');

    var xml = '<?xml version="1.0" encoding="utf-8"?>';
    xml += '<entry xmlns="http://www.w3c.org/2005/Atom">';
    xml += '<title>' + title + '</title>';
    xml += '<content type="' + contentType + '" mode="base64">';
    xml += Base64.encode(fixedImage);
    xml += '</content>';
    xml += '</entry>';

    $.ajax({
        url: opts.endpoint,
        type: 'POST',
        data: xml,
        contentType: 'application/xml+atom',
        beforeSend: function ( xhr ) {
            xhr.setRequestHeader('X-WSSE', 'UsernameToken ' + makeWSSE(opts.username, opts.password) );
        },
        //success: function ( data, type ) {
        //    console.log( data );
        //    console.log( type );
        //},
        error: function ( xhr, text, thrown ){
            alert('Failed to post Image file.');
        },
    });
}

