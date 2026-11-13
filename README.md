# tontineCi

Base Flutter d'une application de tontine, avec Firebase, Riverpod et GoRouter.

## Démarrage

La CI génère le projet Android afin qu'aucun dossier `android/` ne soit conservé dans le dépôt. Pour lancer l'application localement, installer Flutter, puis exécuter `flutter create . --platforms=android --project-name=tontine_ci` et `flutter pub get`.

Avant d'utiliser Firebase, configurer le projet avec FlutterFire et ajouter la configuration native Firebase requise. L'initialisation au démarrage utilise `Firebase.initializeApp()`.

## Structure

- `lib/core/` : application, navigation et conversions Firestore.
- `lib/features/auth/` : utilisateur et écran de compte.
- `lib/features/groups/` : groupes et membres.
- `lib/features/rounds/` : tours de tontine.
- `lib/features/contributions/` : cotisations et leurs statuts.
- `firestore.rules` : règles d'accès limitées aux documents propres à chaque membre.

Le workflow GitHub Actions construit un APK release sur chaque push vers `main` et sur déclenchement manuel, puis le publie comme artifact.