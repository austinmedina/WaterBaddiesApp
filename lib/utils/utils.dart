import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BooleanWrapper {
  bool value;
  BooleanWrapper(this.value);
}

Map<String, double> epaLimits = {
  'Nitrite': 1.0,
  'Lead': 0.01,
  'Cadmium': 0.005,
  'Nitrate': 10.0,
  'Phosphate': 1.0,
  'Microplastics': 1.0,
};

Future<UserCredential> signInWithGoogle() async {
  try {
    final GoogleSignIn googleSignIn = GoogleSignIn();

    // Disconnect the current user to force a new sign-in session. Remove this try statement to persist authentication
    try {
      await googleSignIn.disconnect();
    } on PlatformException catch (e){
      print("Disconnect failed: ${e.message}");
    }

    final GoogleSignInAccount? googleSignInAccount = await googleSignIn.signIn();
    final GoogleSignInAuthentication googleSignInAuthentication = await googleSignInAccount!.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleSignInAuthentication.accessToken,
      idToken: googleSignInAuthentication.idToken,
    );
    return await FirebaseAuth.instance.signInWithCredential(credential);
  } catch (e) {
    print("Error signing in with Google: $e");
    throw e; // Rethrow the error to be handled in the calling function
  }
}