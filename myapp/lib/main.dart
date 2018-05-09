import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

// There Date for iOS
final ThemeData iOSTheme = new ThemeData(
  primarySwatch: Colors.teal,
  primaryColor: Colors.red,
  primaryColorBrightness: Brightness.light,
);

// Theme Data for Android
final ThemeData androidTheme = new ThemeData(
  primarySwatch: Colors.teal,
  accentColor: Colors.red,
);

// Global Variables for Firebase and Analytics
final googleSignIn = new GoogleSignIn();
final analytics = new FirebaseAnalytics();
final auth = FirebaseAuth.instance;
final reference = FirebaseDatabase.instance.reference().child('messages');

// Main method calls home screen
void main() {
  runApp(new RealTimeChatApp());
}

// Home Screen goes to Login Page
class RealTimeChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: "RealTimeChat",
      theme:
          defaultTargetPlatform == TargetPlatform.iOS ? iOSTheme : androidTheme,
      home: new LoginPage(),
    );
  }
}

// Login Page ensures User is logged in prior to chat
class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text("RealTimeChat",
            style: new TextStyle(
                fontStyle: FontStyle.italic, color: Colors.white)),
        elevation: Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
      ),
      body: new Center(
        child: new RaisedButton(
          child: new Text('Login'),
          onPressed: () {
            _login();
            Navigator.push(
              context,
              new MaterialPageRoute(builder: (context) => new ChatWidget()),
            );
          },
        ),
      ),
    );
  }

  // Async function calls EnsureLoggedIn
  void _login() async {
    await _ensureLoggedIn();
  }
}

// Tries to Login silently if User has used app before, else forces Google login
Future<Null> _ensureLoggedIn() async {
  GoogleSignInAccount user = googleSignIn.currentUser;
  if (user == null) user = await googleSignIn.signInSilently();
  if (user == null) {
    user = await googleSignIn.signIn();
    analytics.logLogin();
  }
  if (await auth.currentUser() == null) {
    GoogleSignInAuthentication credentials =
        await googleSignIn.currentUser.authentication;
    await auth.signInWithGoogle(
      idToken: credentials.idToken,
      accessToken: credentials.accessToken,
    );
  }
}

// Message Widget defines what messages look like
@override
class MessageWidget extends StatelessWidget {
  MessageWidget({this.snapshot, this.animation});

  final DataSnapshot snapshot;
  final Animation animation;

  Widget build(BuildContext context) {
    return new SizeTransition(
      sizeFactor: new CurvedAnimation(parent: animation, curve: Curves.easeOut),
      axisAlignment: 0.0,
      child: new Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: new Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            new Container(
              margin: const EdgeInsets.only(right: 16.0),
              child: new CircleAvatar(
                  backgroundImage:
                      new NetworkImage(snapshot.value['senderPhotoUrl'])),
            ),
            new Expanded(
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  new Text(snapshot.value['senderName'],
                      style: Theme.of(context).textTheme.subhead),
                  new Container(
                    margin: const EdgeInsets.only(top: 5.0),
                    child: snapshot.value['imageUrl'] != null
                        ? new Image.network(
                            snapshot.value['imageUrl'],
                            width: 250.0,
                          )
                        : new Text(snapshot.value['text']),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ChatWidget is a StateFul Widget so needs a State
class ChatWidget extends StatefulWidget {
  @override
  State createState() => new ChatWidgetState();
}

// State for for ChatWidget, defines main chat page structure and pulls Firebase
// Data in real-time. Handles both text and Images with Image Picker Library.
class ChatWidgetState extends State<ChatWidget> {
  final TextEditingController _textController = new TextEditingController();
  bool _isComposing = false;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
            title: new Text("RealTimeChat",
                style: new TextStyle(
                    fontStyle: FontStyle.italic, color: Colors.white)),
            elevation:
                Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
            automaticallyImplyLeading: false),
        body: new Column(children: <Widget>[
          new Flexible(
            child: new FirebaseAnimatedList(
              query: reference,
              sort: (a, b) => b.key.compareTo(a.key),
              padding: new EdgeInsets.all(8.0),
              reverse: true,
              itemBuilder:
                  (_, DataSnapshot snapshot, Animation<double> animation) {
                return new MessageWidget(
                    snapshot: snapshot, animation: animation);
              },
            ),
          ),
          new Divider(height: 1.0),
          new Container(
            decoration: new BoxDecoration(color: Theme.of(context).cardColor),
            child: _buildTextComposer(),
          ),
        ]));
  }

  Widget _buildTextComposer() {
    return new IconTheme(
      data: new IconThemeData(color: Theme.of(context).accentColor),
      child: new Container(
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          child: new Row(children: <Widget>[
            new Container(
              margin: new EdgeInsets.symmetric(horizontal: 4.0),
              child: new IconButton(
                  icon: new Icon(Icons.photo_camera),
                  onPressed: () async {
                    await _ensureLoggedIn();
                    File imageFile = await ImagePicker.pickImage();
                    int random = new Random().nextInt(100000);
                    StorageReference ref = FirebaseStorage.instance
                        .ref()
                        .child("image_$random.jpg");
                    StorageUploadTask uploadTask = ref.put(imageFile);
                    Uri downloadUrl = (await uploadTask.future).downloadUrl;
                    _sendMessage(imageUrl: downloadUrl.toString());
                  }),
            ),
            new Flexible(
              child: new TextField(
                controller: _textController,
                onChanged: (String text) {
                  setState(() {
                    _isComposing = text.length > 0;
                  });
                },
                onSubmitted: _handleSubmitted,
                decoration:
                    new InputDecoration.collapsed(hintText: "Send a message"),
              ),
            ),
            new Container(
                margin: new EdgeInsets.symmetric(horizontal: 4.0),
                child: Theme.of(context).platform == TargetPlatform.iOS
                    ? new CupertinoButton(
                        child: new Text("Send"),
                        onPressed: _isComposing
                            ? () => _handleSubmitted(_textController.text)
                            : null,
                      )
                    : new IconButton(
                        icon: new Icon(Icons.send),
                        onPressed: _isComposing
                            ? () => _handleSubmitted(_textController.text)
                            : null,
                      )),
          ]),
          decoration: Theme.of(context).platform == TargetPlatform.iOS
              ? new BoxDecoration(
                  border:
                      new Border(top: new BorderSide(color: Colors.grey[200])))
              : null),
    );
  }

  // Handles submitted messages by doing pre sendMessage checks
  Future<Null> _handleSubmitted(String text) async {
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
    await _ensureLoggedIn();
    _sendMessage(text: text);
  }

  // Pushes message to Firebase
  void _sendMessage({String text, String imageUrl}) {
    reference.push().set({
      'text': text,
      'imageUrl': imageUrl,
      'senderName': googleSignIn.currentUser.displayName,
      'senderPhotoUrl': googleSignIn.currentUser.photoUrl,
    });
    analytics.logEvent(name: 'send_message');
  }
}
