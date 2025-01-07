import 'package:hive_flutter/adapters.dart';
import 'package:matrixclient2base/appconfig.dart';
import 'package:matrixclient2base/modules/base/vwapicall/synctokenblock/synctokenblock.dart';
import 'package:matrixclient2base/modules/base/vwapicall/vwapicallresponse/vwapicallresponse.dart';
import 'package:matrixclient2base/modules/base/vwauthutil/vwauthutil.dart';
import 'package:matrixclient2base/modules/base/vwclassencodedjson/vwclassencodedjson.dart';
import 'package:matrixclient2base/modules/base/vwdataformat/vwfiedvalue/vwfieldvalue.dart';
import 'package:matrixclient2base/modules/base/vwdataformat/vwrowdata/vwrowdata.dart';
import 'package:matrixclient2base/modules/base/vwloginresponse/vwloginresponse.dart';
import 'package:matrixclient2base/modules/base/vwnode/vwnode.dart';
import 'package:uuid/uuid.dart';
import 'package:vwform/modules/vwgraphqlclient/modules/vwgraphqlquery/vwgraphqlquery.dart';
import 'package:vwform/modules/vwgraphqlclient/modules/vwpgraphqlserverresponse/vwgraphqlserverresponse.dart';
import 'package:vwform/modules/vwgraphqlclient/vwgraphqlclient.dart';
import 'dart:convert';

import 'package:vwutil/modules/util/vwdateutil.dart';

class VwNodeStoreOnHive {
  VwNodeStoreOnHive({required this.boxName});

  final String boxName;

  static Future<int> boxContentCount(String boxName) async {
    Box<dynamic> box = await Hive.openBox(boxName);
    int result = box.length;
    return result;
  }

  Future<bool> deleteRecord(int index) async {
    bool returnValue = false;
    try {
      Box<dynamic> box = await Hive.openBox(this.boxName);

      if (index < box.length) {
        await box.deleteAt(index);
        returnValue = true;
      }
    } catch (error) {}

    return returnValue;
  }

  Future<VwNode?> getRecord(int index) async {
    VwNode? returnValue;

    Box<dynamic> box = await Hive.openBox(this.boxName);

    if (box.length > 0 && index < box.length) {
      VwClassEncodedJson currentClassEncodedJson = box.getAt(index);

      String jsonEncoded = json.encode(currentClassEncodedJson.data);

      Map<String, dynamic> jsonDecoded = json.decode(jsonEncoded);

      returnValue = VwNode.fromJson(jsonDecoded);

      return returnValue;
    }
  }

  Future<VwNode?> getRecordByParentNodeIdAndDisplayName(
      {required String parentNodeId, required String displayName}) async {
    VwNode? returnValue;

    List<int> selectedNodes = await this.getIndexByParentNodeIdAndDisplayName(
        parentNodeId: parentNodeId, displayName: displayName);

    for (int la = 0; la < selectedNodes.length; la++) {
      returnValue = await this.getRecord(selectedNodes.elementAt(la));
      break;
    }

    /*
    String boxName = AppConfig.unsyncedRecordFieldname;

    Box<dynamic> box = await Hive.openBox(boxName);


    if (box.length > 0) {
      for (int la = 0; la < box.length; la++) {
        try {
          VwClassEncodedJson currentClassEncodedJson =
              box.getAt(box.length - 1);
          if (currentClassEncodedJson.className == "VwNode") {
            Map<String,dynamic> currentData=currentClassEncodedJson.data;
            VwNode currentNode = VwNode.fromJson(currentData);
            if (currentNode.parentNodeId == parentNodeId && currentNode.displayName==displayName ) {
              returnValue.add(currentClassEncodedJson);
            }
          }
        } catch (error) {
          print(
              "error catched on   static Future<List<VwClassEncodedJson>> getUnscyncedPopByParentNodeId: " +
                  error.toString());
        }
      }
    }*/

    return returnValue;
  }

  Future<List<int>> getIndexByParentNodeIdAndDisplayName(
      {required String parentNodeId, required String displayName}) async {
    List<int> returnValue = [];

    final int length = await VwNodeStoreOnHive.boxContentCount(this.boxName);
    for (int la = 0; la < length; la++) {
      VwNode? currentNode = await this.getRecord(la);
      if (currentNode!.parentNodeId != null &&
          currentNode.displayName != null &&
          currentNode.parentNodeId == parentNodeId &&
          currentNode.displayName == displayName) {
        returnValue.add(la);
      }
    }


    return returnValue;
  }



  Future<int> pushRecord(VwNode node) async {
    int result = 0;
    try {
      String tempDataString = json.encode(node.toJson());
      Map<String, dynamic> tempDataDyn = json.decode(tempDataString);

      VwClassEncodedJson classEncodedNodeEncapsulator = VwClassEncodedJson(
          instanceId: node.recordId, data: tempDataDyn, className: "VwNode");

      List<int> recordList = await this.getIndexByParentNodeIdAndDisplayName(
          parentNodeId: node.parentNodeId!, displayName: node.displayName);

      for (int la = recordList.length - 1; la >= 0; la--) {
        await this.deleteRecord(recordList.elementAt(la));
      }
      Box<dynamic> box = await Hive.openBox(this.boxName);

      final int countBefore = box.length;

      result = await box.add(classEncodedNodeEncapsulator);

      final int countAfter = box.length;
    } catch (error) {
      print("Error catched on Future<int> pushRecord(VwNode node) async:" +
          error.toString());
    }

    return result;
  }

  static Future<SyncTokenBlock?> getToken({required String loginSessionId,   required int count,required String apiCallId}) async {
    SyncTokenBlock? returnValue;
    try {
      VwFieldValue fieldValue1 = VwFieldValue(
          fieldName: "count",
          valueNumber: count.toDouble(),
          valueTypeId: VwFieldValue.vatNumber);
      VwFieldValue fieldValue2 = VwFieldValue(
          fieldName: "apiCallId",
          valueString: apiCallId,
          valueTypeId: VwFieldValue.vatString);

      VwRowData apiCallParam = VwRowData(timestamp: VwDateUtil.nowTimestamp(),
          recordId: Uuid().v4(), fields: <VwFieldValue>[fieldValue1, fieldValue2]);

      //VwLoginResponse ? loginResponse=await VwAuthUtil .getSavedLoggedInLoginResponseInLocal();


        VwGraphQlQuery graphQlQuery = VwGraphQlQuery(
            graphQlFunctionName: "apiCall",
            apiCallId: 'getToken',
            loginSessionId: loginSessionId,
            parameter: apiCallParam);

        VwGraphQlServerResponse graphQlServerResponse =
        await VwGraphQlClient.httpPostGraphQl(
            url: AppConfig.serverAddress, graphQlQuery: graphQlQuery);

        if (graphQlServerResponse.apiCallResponse != null) {
         if(graphQlServerResponse.apiCallResponse!.responseStatusCode==200)
           {
             returnValue=SyncTokenBlock(isServerResponded: true, respondedDate: DateTime.now(), loginSessionId: loginSessionId, tokenList: []);
           }

          if (graphQlServerResponse.apiCallResponse!.responseType ==
              VwApiCallResponse.rtClassEncodedJson) {
            if (graphQlServerResponse
                .apiCallResponse!.valueResponseClassEncodedJson!.className ==
                "SyncTokenBlock") {
              returnValue = SyncTokenBlock.fromJson(graphQlServerResponse
                  .apiCallResponse!.valueResponseClassEncodedJson!.data!);
            }
          }
        }

    } catch (error) {
      print(
          "Error catched on Future<List<String>> getToken(int count) async: " +
              error.toString());
    }

    return returnValue;
  }

  Future<int> tokenizingNode(
  {
    required String loginSessionId
}
      ) async {
    int returnValue = 0;
    try {
      int unsyncedCount = await VwNodeStoreOnHive.boxContentCount(this.boxName);
      int untokenizedCount = await this.untokenizedCount();

      if(untokenizedCount>0) {
        SyncTokenBlock? syncTokenBlock =
        await VwNodeStoreOnHive.getToken(
            loginSessionId: loginSessionId,
            count: untokenizedCount, apiCallId: "syncNode");

        if (syncTokenBlock != null) {
          for (int la = 0;
          la < unsyncedCount ;
          la++) {
            VwNode? currentNode = await this.getRecord(la);

            if (currentNode != null && currentNode.upsyncToken == null) {
              String currentToken = syncTokenBlock.tokenList.elementAt(0);
              syncTokenBlock.tokenList.removeAt(0);
              currentNode.upsyncToken = currentToken;
              await VwNodeStoreOnHive(
                  boxName: AppConfig.unsyncedRecordFieldname).pushRecord(
                  currentNode);
            }
          }
        }
      }
    } catch (error) {}
    return returnValue;
  }

  Future<int> untokenizedCount() async {
    int returnValue = 0;
    try {
      int unsyncedCount = await VwNodeStoreOnHive.boxContentCount(this.boxName);

      for (int la = 0; la < unsyncedCount; la++) {
        VwNode? currentNode = await this.getRecord(la);

        if (currentNode != null && currentNode.upsyncToken == null) {
          returnValue++;
        }
      }
    } catch (error) {}
    return returnValue;
  }

  Future<bool> syncToServer({required String loginSessionId}) async {
    bool returnValue = false;
    try {
      List<VwFieldValue> fieldValueList = <VwFieldValue>[];

      int unsyncedCount = await VwNodeStoreOnHive.boxContentCount(this.boxName);

      await this.tokenizingNode(loginSessionId: loginSessionId);

      for (int la = 0; la < unsyncedCount; la++) {
        VwNode? currentNode = await this.getRecord(la);

        if (currentNode != null && currentNode.upsyncToken != null) {
          String nodeJsonEncoded = json.encode(currentNode.toJson());
          Map<String, dynamic> nodeJsonDecoded = json.decode(nodeJsonEncoded);

          VwClassEncodedJson currentNodeEncodedJson = VwClassEncodedJson(
              instanceId: currentNode.upsyncToken!,
              data: nodeJsonDecoded,
              className: "VwNode",
              createdOnClient: DateTime.now());

          VwFieldValue fieldValue1 = VwFieldValue(
              fieldName: Uuid().v4(),
              valueTypeId: VwFieldValue.vatClassEncodedJson,
              valueClassEncodedJson: currentNodeEncodedJson);

          fieldValueList.add(fieldValue1);
        }
      }

      VwRowData apiCallParam =
          VwRowData(timestamp: VwDateUtil.nowTimestamp(),recordId: Uuid().v4(), fields: fieldValueList);

      VwLoginResponse ? loginResponse=await VwAuthUtil .getSavedLoggedInLoginResponseInLocal();



      VwGraphQlQuery graphQlQuery = VwGraphQlQuery(
          graphQlFunctionName: "apiCall",
          apiCallId: 'syncNode',
          loginSessionId: loginResponse!.loginSessionId!,
          parameter: apiCallParam);

      VwGraphQlServerResponse response = await VwGraphQlClient.httpPostGraphQl(
          url: AppConfig.serverAddress, graphQlQuery: graphQlQuery);

      /*
      if(response.httpResponse!=null && response.httpResponse!.statusCode==200 && response.apiCallResponse!=null && response.apiCallResponse!.valueResponseClassEncodedJson!=null && response.apiCallResponse!.valueResponseClassEncodedJson!.className=="VwNodeUpsyncResultPackage" )
      {
        Map<String,dynamic> currentDate= response.apiCallResponse!.valueResponseClassEncodedJson!.data!;

        VwNodeUpsyncResultPackage nodeUpsyncResultPackage=VwNodeUpsyncResultPackage.fromJson(currentDate);



      }*/
    } catch (error) {
      print("Error catched on Future<bool> syncToServer() = "+ error.toString());
    }

    return returnValue;
  }
}
