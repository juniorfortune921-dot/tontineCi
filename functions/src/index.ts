import { randomInt } from 'node:crypto';
import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

initializeApp();

const db = getFirestore();
const MAX_MEMBERS = 50;
const INVITE_CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const INVITE_CODE_LENGTH = 8;
const INVITE_CODE_PATTERN = /^[A-HJ-KMNP-Z2-9]{8}$/;

function generateInviteCode(): string {
  return Array.from({ length: INVITE_CODE_LENGTH }, () =>
    INVITE_CODE_ALPHABET[randomInt(INVITE_CODE_ALPHABET.length)],
  ).join('');
}

export const ping = onCall({ region: 'europe-west1' }, (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Connexion requise.');
  }

  return { ok: true, uid };
});

export const createInviteCode = onCall(
  { region: 'europe-west1' },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Connexion requise.');
    }

    const groupId = request.data?.groupId;
    if (typeof groupId !== 'string' || groupId.length === 0) {
      throw new HttpsError('invalid-argument', 'Identifiant de section invalide.');
    }

    let code = '';
    await db.runTransaction(async (transaction) => {
      const groupRef = db.collection('groups').doc(groupId);
      const groupSnapshot = await transaction.get(groupRef);
      if (!groupSnapshot.exists) {
        throw new HttpsError('not-found', 'Section introuvable.');
      }
      if (groupSnapshot.data()?.ownerId !== uid) {
        throw new HttpsError(
          'permission-denied',
          'Non autorisé à créer un code pour cette section.',
        );
      }

      const activeInvites = await transaction.get(
        db.collection('invites')
          .where('groupId', '==', groupId)
          .where('active', '==', true),
      );

      let inviteRef;
      do {
        code = generateInviteCode();
        inviteRef = db.collection('invites').doc(code);
      } while ((await transaction.get(inviteRef)).exists);

      for (const invite of activeInvites.docs) {
        transaction.update(invite.ref, { active: false });
      }
      transaction.create(inviteRef, {
        groupId,
        createdBy: uid,
        createdAt: FieldValue.serverTimestamp(),
        active: true,
      });
    });

    return { code };
  },
);

export const joinGroupByCode = onCall(
  { region: 'europe-west1' },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Connexion requise.');
    }

    const code = request.data?.code;
    if (typeof code !== 'string' || !INVITE_CODE_PATTERN.test(code)) {
      throw new HttpsError('invalid-argument', 'Code invalide.');
    }

    let groupId = '';
    await db.runTransaction(async (transaction) => {
      const inviteRef = db.collection('invites').doc(code);
      const inviteSnapshot = await transaction.get(inviteRef);
      if (!inviteSnapshot.exists || inviteSnapshot.data()?.active !== true) {
        throw new HttpsError('not-found', 'Code invalide ou expiré.');
      }

      const inviteGroupId = inviteSnapshot.data()?.groupId;
      if (typeof inviteGroupId !== 'string' || inviteGroupId.length === 0) {
        throw new HttpsError('not-found', 'Code invalide ou expiré.');
      }

      const groupRef = db.collection('groups').doc(inviteGroupId);
      const memberRef = groupRef.collection('members').doc(uid);
      const [groupSnapshot, memberSnapshot] = await Promise.all([
        transaction.get(groupRef),
        transaction.get(memberRef),
      ]);
      if (!groupSnapshot.exists) {
        throw new HttpsError('not-found', 'Section introuvable.');
      }

      const memberIds = groupSnapshot.data()?.memberIds;
      if (!Array.isArray(memberIds)) {
        throw new HttpsError('failed-precondition', 'Impossible de rejoindre cette section.');
      }
      if (memberSnapshot.exists || memberIds.includes(uid)) {
        throw new HttpsError('already-exists', 'Vous êtes déjà membre de cette section.');
      }
      if (memberIds.length >= MAX_MEMBERS) {
        throw new HttpsError('resource-exhausted', 'Cette section est pleine.');
      }

      transaction.update(groupRef, {
        memberIds: FieldValue.arrayUnion(uid),
      });
      transaction.create(memberRef, {
        userId: uid,
        groupId: inviteGroupId,
        joinedAt: FieldValue.serverTimestamp(),
      });
      groupId = inviteGroupId;
    });

    return { groupId };
  },
);