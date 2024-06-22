import 'dart:convert';
import 'package:http/http.dart' as http;

class EbayLinkGenerator {
  final String appId;

  EbayLinkGenerator(this.appId);

  Future<String> generateLink(String keywords, {String responseFormat = 'JSON', String operationName = 'findItemsByKeywords', String serviceVersion = '1.0.0', int entriesPerPage = 2}) async {
    print('keywords: $keywords');

    final Map<String, String> queryParams = {
      'OPERATION-NAME': operationName,
      'SERVICE-VERSION': serviceVersion,
      'SECURITY-APPNAME': appId,
      'RESPONSE-DATA-FORMAT': responseFormat,
      'REST-PAYLOAD': '',
      'keywords': keywords,
      'paginationInput.entriesPerPage': entriesPerPage.toString(),
    };

    final uri = Uri.https('svcs.ebay.com', '/services/search/FindingService/v1', queryParams);

    final headers = {
      'Accept': 'application/json',
    };

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      // Extract the viewItemURL from the response data
      List<String> itemUrls = [];
      final searchResult = responseData['findItemsByKeywordsResponse'][0]['searchResult'][0];
      if (searchResult['@count'] != '0') {
        final items = searchResult['item'];
        for (var item in items) {
          itemUrls.add(item['viewItemURL'][0]);
        }
      }

      return itemUrls[0];
    } else {
      throw Exception('Failed to generate link: ${response.statusCode}');
    }
  }
}
