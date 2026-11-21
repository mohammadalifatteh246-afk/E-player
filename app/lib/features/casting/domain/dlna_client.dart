import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Client that dispatches UPnP AVTransport SOAP actions to DLNA Smart TVs.
/// Controls media streaming playback on Samsung, LG, Sony, Roku, and generic renderers.
class DlnaClient {
  final HttpClient Function()? clientFactory;

  DlnaClient({this.clientFactory});

  /// Sends SetAVTransportURI to instruct the TV to load the local HTTP media stream.
  Future<bool> setAvTransportUri(
    String controlUrl,
    String streamUrl, {
    String title = 'E-Player Stream',
  }) async {
    final didlMetadata =
        '&lt;DIDL-Lite xmlns=&quot;urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/&quot; '
        'xmlns:dc=&quot;http://purl.org/dc/elements/1.1/&quot; '
        'xmlns:upnp=&quot;urn:schemas-upnp-org:metadata-1-0/upnp/&quot;&gt;'
        '&lt;item id=&quot;0&quot; parentID=&quot;-1&quot; restricted=&quot;1&quot;&gt;'
        '&lt;dc:title&gt;$title&lt;/dc:title&gt;'
        '&lt;upnp:class&gt;object.item.videoItem&lt;/upnp:class&gt;'
        '&lt;res protocolInfo=&quot;http-get:*:video/mp4:*&quot;&gt;$streamUrl&lt;/res&gt;'
        '&lt;/item&gt;&lt;/DIDL-Lite&gt;';

    final body = '<?xml version="1.0" encoding="utf-8"?>\r\n'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\r\n'
        '  <s:Body>\r\n'
        '    <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">\r\n'
        '      <InstanceID>0</InstanceID>\r\n'
        '      <CurrentURI>$streamUrl</CurrentURI>\r\n'
        '      <CurrentURIMetaData>$didlMetadata</CurrentURIMetaData>\r\n'
        '    </u:SetAVTransportURI>\r\n'
        '  </s:Body>\r\n'
        '</s:Envelope>';

    return _postSoap(controlUrl, 'SetAVTransportURI', body);
  }

  /// Sends Play action to start playback on the TV.
  Future<bool> play(String controlUrl) async {
    final body = '<?xml version="1.0" encoding="utf-8"?>\r\n'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\r\n'
        '  <s:Body>\r\n'
        '    <u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">\r\n'
        '      <InstanceID>0</InstanceID>\r\n'
        '      <Speed>1</Speed>\r\n'
        '    </u:Play>\r\n'
        '  </s:Body>\r\n'
        '</s:Envelope>';

    return _postSoap(controlUrl, 'Play', body);
  }

  /// Sends Pause action to pause playback on the TV.
  Future<bool> pause(String controlUrl) async {
    final body = '<?xml version="1.0" encoding="utf-8"?>\r\n'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\r\n'
        '  <s:Body>\r\n'
        '    <u:Pause xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">\r\n'
        '      <InstanceID>0</InstanceID>\r\n'
        '    </u:Pause>\r\n'
        '  </s:Body>\r\n'
        '</s:Envelope>';

    return _postSoap(controlUrl, 'Pause', body);
  }

  /// Sends Stop action to stop playback on the TV.
  Future<bool> stop(String controlUrl) async {
    final body = '<?xml version="1.0" encoding="utf-8"?>\r\n'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\r\n'
        '  <s:Body>\r\n'
        '    <u:Stop xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">\r\n'
        '      <InstanceID>0</InstanceID>\r\n'
        '    </u:Stop>\r\n'
        '  </s:Body>\r\n'
        '</s:Envelope>';

    return _postSoap(controlUrl, 'Stop', body);
  }

  Future<bool> _postSoap(String controlUrl, String action, String body) async {
    HttpClient? client;
    try {
      client = clientFactory?.call() ?? HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);

      final uri = Uri.parse(controlUrl);
      final req = await client.postUrl(uri).timeout(const Duration(seconds: 4));
      req.headers.set('Content-Type', 'text/xml; charset="utf-8"');
      req.headers.set('SOAPACTION', '"urn:schemas-upnp-org:service:AVTransport:1#$action"');

      final bytes = utf8.encode(body);
      req.contentLength = bytes.length;
      req.add(bytes);

      final resp = await req.close().timeout(const Duration(seconds: 4));
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      debugPrint('DlnaClient SOAP action $action failed on $controlUrl: $e');
      return false;
    } finally {
      client?.close();
    }
  }
}
