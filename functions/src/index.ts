import { HttpsError, onCall } from 'firebase-functions/v2/https';

export const ping = onCall({ region: 'europe-west1' }, (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Connexion requise.');
  }

  return { ok: true, uid };
});