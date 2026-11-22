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

function shuffle<T>(items: T[]): void {
  for (let index = items.length - 1; index > 0; index -= 1) {
    const swapIndex = randomInt(index + 1);
    [items[index], items[swapIndex]] = [items[swapIndex], items[index]];
  }
}

function scheduledDate(startDate: Date, frequency: string, offset: number): Date {
  const date = new Date(startDate);
  if (frequency === 'daily') {
    date.setUTCDate(date.getUTCDate() + offset);
    return date;
  }
  if (frequency === 'weekly') {
    date.setUTCDate(date.getUTCDate() + offset * 7);
    return date;
  }

  const monthIndex = startDate.getUTCMonth() + offset;
  const year = startDate.getUTCFullYear() + Math.floor(monthIndex / 12);
  const month = monthIndex % 12;
  const day = Math.min(
    startDate.getUTCDate(),
    new Date(Date.UTC(year, month + 1, 0)).getUTCDate(),
  );
  date.setUTCFullYear(year, month, day);
  return date;
}

export const ping = onCall({ region: 'europe-west1' }, (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Connexion requise.');
  }

  return { ok: true, uid };
});

export const getPayeeInfo = onCall(
  { region: 'europe-west1' },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Connexion requise.');
    }

    const groupId = request.data?.groupId;
    const roundId = request.data?.roundId;
    if (
      typeof groupId !== 'string' ||
      groupId.length === 0 ||
      typeof roundId !== 'string' ||
      roundId.length === 0
    ) {
      throw new HttpsError('invalid-argument', 'Identifiant de tour invalide.');
    }

    const groupRef = db.collection('groups').doc(groupId);
    const [groupSnapshot, memberSnapshot] = await Promise.all([
      groupRef.get(),
      groupRef.collection('members').doc(uid).get(),
    ]);
    if (!groupSnapshot.exists) {
      throw new HttpsError('not-found', 'Section introuvable.');
    }
    if (!memberSnapshot.exists) {
      throw new HttpsError(
        'permission-denied',
        'Vous devez être membre de cette section.',
      );
    }

    const roundsRef = groupRef.collection('rounds');
    const [roundSnapshot, roundsSnapshot] = await Promise.all([
      roundsRef.doc(roundId).get(),
      roundsRef.get(),
    ]);
    const round = roundSnapshot.data();
    const currentRound = roundsSnapshot.docs
      .filter((document) => document.data().status !== 'completed')
      .sort((first, second) => first.data().number - second.data().number)[0];

    if (
      !roundSnapshot.exists ||
      round?.groupId !== groupId ||
      currentRound?.id !== roundId
    ) {
      throw new HttpsError(
        'failed-precondition',
        "Ce tour n'est pas en cours",
      );
    }

    const recipientId = round.recipientId;
    if (typeof recipientId !== 'string' || recipientId.length === 0) {
      throw new HttpsError('failed-precondition', "Ce tour n'est pas en cours");
    }
    if (recipientId === uid) {
      throw new HttpsError(
        'permission-denied',
        'Le bénéficiaire ne peut pas consulter ses propres informations de paiement.',
      );
    }

    const recipientSnapshot = await db.collection('users').doc(recipientId).get();
    const recipient = recipientSnapshot.data();
    const paymentMethod = recipient?.paymentMethod;
    const paymentNumber = recipient?.paymentNumber;
    if (
      typeof paymentMethod !== 'string' ||
      !['wave', 'orange', 'mtn', 'moov'].includes(paymentMethod) ||
      typeof paymentNumber !== 'string' ||
      paymentNumber.length === 0
    ) {
      throw new HttpsError(
        'failed-precondition',
        "Le bénéficiaire n'a pas encore enregistré son moyen de paiement",
      );
    }

    const displayName = recipient?.displayName;
    const roundRecipientName = round.recipientName;
    return {
      recipientName:
        typeof displayName === 'string' && displayName.trim().length > 0
          ? displayName
          : typeof roundRecipientName === 'string' &&
              roundRecipientName.trim().length > 0
            ? roundRecipientName
            : 'Membre',
      paymentMethod,
      paymentNumber,
    };
  },
);

export const closeRoundIfComplete = onCall(
  { region: 'europe-west1' },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Connexion requise.');
    }

    const groupId = request.data?.groupId;
    const roundId = request.data?.roundId;
    if (
      typeof groupId !== 'string' ||
      groupId.length === 0 ||
      typeof roundId !== 'string' ||
      roundId.length === 0
    ) {
      throw new HttpsError('invalid-argument', 'Identifiant de tour invalide.');
    }

    try {
      return await db.runTransaction(async (transaction) => {
        const groupRef = db.collection('groups').doc(groupId);
        const roundRef = groupRef.collection('rounds').doc(roundId);
        const memberRef = groupRef.collection('members').doc(uid);
        const [roundSnapshot, memberSnapshot] = await Promise.all([
          transaction.get(roundRef),
          transaction.get(memberRef),
        ]);

        if (!memberSnapshot.exists) {
          throw new HttpsError(
            'permission-denied',
            'Vous devez être membre de cette section.',
          );
        }
        if (!roundSnapshot.exists || roundSnapshot.data()?.groupId !== groupId) {
          throw new HttpsError('not-found', 'Tour introuvable dans cette section.');
        }

        const round = roundSnapshot.data();
        if (round?.status === 'completed') {
          return { completed: true, alreadyClosed: true };
        }

        const recipientId = round?.recipientId;
        const roundNumber = round?.number;
        if (
          typeof recipientId !== 'string' ||
          typeof roundNumber !== 'number' ||
          !Number.isInteger(roundNumber)
        ) {
          throw new HttpsError('failed-precondition', 'Les données du tour sont invalides.');
        }

        const membersRef = groupRef.collection('members');
        const contributionsRef = groupRef.collection('contributions');
        const [membersSnapshot, contributionsSnapshot] = await Promise.all([
          transaction.get(membersRef),
          transaction.get(contributionsRef.where('roundId', '==', roundId)),
        ]);
        const expectedMemberIds = new Set(
          membersSnapshot.docs
            .map((member) => member.id)
            .filter((memberId) => memberId !== recipientId),
        );
        const confirmedMemberIds = new Set(
          contributionsSnapshot.docs
            .filter((contribution) => contribution.data().status === 'confirme')
            .map((contribution) => contribution.data().memberId)
            .filter(
              (memberId): memberId is string =>
                typeof memberId === 'string' && expectedMemberIds.has(memberId),
            ),
        );

        if (confirmedMemberIds.size < expectedMemberIds.size) {
          return {
            completed: false,
            confirmed: confirmedMemberIds.size,
            expected: expectedMemberIds.size,
          };
        }

        const nextRoundSnapshot = await transaction.get(
          groupRef
            .collection('rounds')
            .where('number', '==', roundNumber + 1)
            .limit(1),
        );
        const nextRound = nextRoundSnapshot.docs[0];
        transaction.update(roundRef, { status: 'completed' });

        return {
          completed: true,
          nextRound: nextRound ? roundNumber + 1 : null,
        };
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      throw new HttpsError(
        'internal',
        'Impossible de vérifier la clôture de ce tour.',
      );
    }
  },
);

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

    const userSnapshot = await db.collection('users').doc(uid).get();
    const profileName = userSnapshot.data()?.displayName;
    const normalizedName =
      typeof profileName === 'string' ? profileName.trim() : '';
    const displayName = normalizedName
      ? normalizedName.slice(0, 40)
      : 'Membre';

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
        displayName,
      });
      groupId = inviteGroupId;
    });

    return { groupId };
  },
);

export const startTontine = onCall(
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

    try {
      await db.runTransaction(async (transaction) => {
        const groupRef = db.collection('groups').doc(groupId);
        const groupSnapshot = await transaction.get(groupRef);
        if (!groupSnapshot.exists) {
          throw new HttpsError('not-found', 'Section introuvable.');
        }

        const group = groupSnapshot.data();
        if (group?.ownerId !== uid) {
          throw new HttpsError(
            'permission-denied',
            'Seul le propriétaire peut lancer la section.',
          );
        }

        const membersRef = groupRef.collection('members');
        const roundsRef = groupRef.collection('rounds');
        const [membersSnapshot, roundsSnapshot] = await Promise.all([
          transaction.get(membersRef.orderBy('joinedAt', 'asc')),
          transaction.get(roundsRef.limit(1)),
        ]);

        if (!roundsSnapshot.empty) {
          throw new HttpsError(
            'already-exists',
            'Cette section a déjà été lancée.',
          );
        }

        const members = membersSnapshot.docs;
        if (members.length < 2) {
          throw new HttpsError(
            'failed-precondition',
            'Il faut au moins deux membres pour lancer la section.',
          );
        }

        const frequency = group?.frequency;
        if (!['daily', 'weekly', 'monthly'].includes(frequency)) {
          throw new HttpsError(
            'failed-precondition',
            'La fréquence de la section est invalide.',
          );
        }

        const membersWithProfiles = await Promise.all(
          members.map(async (member) => {
            const recipientId = member.data().userId;
            if (typeof recipientId !== 'string' || recipientId.length === 0) {
              throw new HttpsError(
                'failed-precondition',
                'Un membre de la section est invalide.',
              );
            }
            const profileSnapshot = await transaction.get(
              db.collection('users').doc(recipientId),
            );
            const profile = profileSnapshot.data();
            const displayName = profile?.displayName;
            return {
              recipientId,
              recipientName:
                typeof displayName === 'string' && displayName.trim().length > 0
                  ? displayName
                  : 'Membre',
              hasPaymentMethod:
                typeof profile?.paymentMethod === 'string' &&
                profile.paymentMethod.length > 0 &&
                typeof profile.paymentNumber === 'string' &&
                profile.paymentNumber.length > 0,
            };
          }),
        );

        const membersMissingPayment = membersWithProfiles.filter(
          (member) => !member.hasPaymentMethod,
        );
        if (membersMissingPayment.length > 0) {
          const names = membersMissingPayment
            .slice(0, 10)
            .map((member) => member.recipientName)
            .join(', ');
          throw new HttpsError(
            'failed-precondition',
            `${membersMissingPayment.length} membre(s) n'ont pas enregistré leur moyen de paiement : ${names}`,
          );
        }

        const distributionMode = group?.distributionMode;
        if (distributionMode === 'tirage') {
          shuffle(membersWithProfiles);
        } else if (distributionMode !== 'ordre') {
          throw new HttpsError(
            'failed-precondition',
            'Le mode de distribution de la section est invalide.',
          );
        }

        const firstScheduledDate = new Date();
        firstScheduledDate.setUTCDate(firstScheduledDate.getUTCDate() + 1);

        membersWithProfiles.forEach(({ recipientId, recipientName }, index) => {
          const number = index + 1;
          transaction.create(roundsRef.doc(`round-${number}`), {
            groupId,
            number,
            recipientId,
            recipientName,
            scheduledAt: scheduledDate(firstScheduledDate, frequency, index),
            status: 'scheduled',
          });
        });
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      throw new HttpsError(
        'internal',
        'Impossible de générer le calendrier des tours.',
      );
    }

    return { groupId };
  },
);