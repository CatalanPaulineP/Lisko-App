const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'lisko-25162';

jest.setTimeout(30000);

describe('LisKo Firestore Security Rules Behavioral Emulator Tests', () => {
  let testEnv;

  beforeAll(async () => {
    const rulesPath = path.join(__dirname, '..', 'firestore.rules');
    const rules = fs.readFileSync(rulesPath, 'utf8');

    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: rules,
        host: '127.0.0.1',
        port: 8080,
      },
    });
  });

  afterAll(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  beforeEach(async () => {
    if (testEnv) {
      await testEnv.clearFirestore();
    }
  });

  const fixedStartedAt = new Date('2026-03-30T10:00:00Z');

  // Valid Trip Document Helper
  function getValidTrip(userId, startedAt = fixedStartedAt) {
    return {
      userId: userId,
      installationId: 'inst_1792656876196_123456_654321',
      destination: 'Campus',
      estimatedTravelMinutes: 45,
      startedAt: startedAt,
      status: 'active',
    };
  }

  // Valid Emergency Event Document Helper
  function getValidEmergencyEvent(userId) {
    return {
      userId: userId,
      installationId: 'inst_1792656876196_123456_654321',
      deviceId: 'local_device',
      tripId: 'trip_123',
      latitude: 14.869725,
      longitude: 120.999082,
      emergencyType: 'SOS',
      triggeredAt: new Date('2026-03-30T10:00:00Z'),
      status: 'active',
    };
  }

  // --------------------------------------------------------------------------
  // 1. UNAUTHENTICATED USERS
  // --------------------------------------------------------------------------
  test('Unauthenticated users CANNOT read trip documents', async () => {
    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(unauthDb.collection('trips').doc('trip_1').get());
  });

  test('Unauthenticated users CANNOT create or update trip documents', async () => {
    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      unauthDb.collection('trips').doc('trip_1').set(getValidTrip('user_a'))
    );
  });

  test('Unauthenticated users CANNOT read emergency events', async () => {
    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(unauthDb.collection('emergency_events').doc('event_1').get());
  });

  test('Unauthenticated users CANNOT create emergency events', async () => {
    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      unauthDb.collection('emergency_events').doc('event_1').set(getValidEmergencyEvent('user_a'))
    );
  });

  // --------------------------------------------------------------------------
  // 2. AUTHORIZED OWNERSHIP (USER A)
  // --------------------------------------------------------------------------
  test('User A CAN create and read their own trip document', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    const tripDoc = userADb.collection('trips').doc('trip_a1');

    await assertSucceeds(tripDoc.set(getValidTrip('user_a')));
    await assertSucceeds(tripDoc.get());
  });

  test('User A CAN update their trip status without modifying immutable fields', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    const tripDoc = userADb.collection('trips').doc('trip_a1');

    // Create trip with fixed startedAt timestamp
    await tripDoc.set(getValidTrip('user_a'));

    // Update status preserving identical startedAt, destination, installationId, userId
    const updatePayload = {
      ...getValidTrip('user_a'),
      status: 'arrived',
      completedAt: new Date(),
    };

    await assertSucceeds(tripDoc.set(updatePayload, { merge: true }));
  });

  test('User A CANNOT modify immutable fields (startedAt, destination, userId, installationId) on update', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    const tripDoc = userADb.collection('trips').doc('trip_a1');

    await tripDoc.set(getValidTrip('user_a'));

    // Attempt to change destination
    const badUpdate = {
      ...getValidTrip('user_a'),
      destination: 'Hacked Location',
    };

    await assertFails(tripDoc.set(badUpdate, { merge: true }));
  });

  // --------------------------------------------------------------------------
  // 3. CROSS-USER ISOLATION & OWNER SPOOFING (USER B vs USER A)
  // --------------------------------------------------------------------------
  test('User B CANNOT read User A\'s trip document', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    await userADb.collection('trips').doc('trip_a1').set(getValidTrip('user_a'));

    const userBDb = testEnv.authenticatedContext('user_b').firestore();
    await assertFails(userBDb.collection('trips').doc('trip_a1').get());
  });

  test('User B CANNOT update User A\'s trip document', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    await userADb.collection('trips').doc('trip_a1').set(getValidTrip('user_a'));

    const userBDb = testEnv.authenticatedContext('user_b').firestore();
    const badPayload = {
      ...getValidTrip('user_a'),
      status: 'cancelled',
    };

    await assertFails(userBDb.collection('trips').doc('trip_a1').set(badPayload, { merge: true }));
  });

  test('User B CANNOT create a trip document claiming User A\'s userId', async () => {
    const userBDb = testEnv.authenticatedContext('user_b').firestore();
    // User B tries to set userId = 'user_a'
    const spoofedTrip = getValidTrip('user_a');

    await assertFails(userBDb.collection('trips').doc('spoofed_doc').set(spoofedTrip));
  });

  // --------------------------------------------------------------------------
  // 4. EMERGENCY EVENTS
  // --------------------------------------------------------------------------
  test('User A CAN create and read their own emergency event', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    const eventDoc = userADb.collection('emergency_events').doc('event_a1');

    await assertSucceeds(eventDoc.set(getValidEmergencyEvent('user_a')));
    await assertSucceeds(eventDoc.get());
  });

  test('User B CANNOT read User A\'s emergency event', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    await userADb.collection('emergency_events').doc('event_a1').set(getValidEmergencyEvent('user_a'));

    const userBDb = testEnv.authenticatedContext('user_b').firestore();
    await assertFails(userBDb.collection('emergency_events').doc('event_a1').get());
  });

  test('Emergency events CANNOT be updated by clients', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    await userADb.collection('emergency_events').doc('event_a1').set(getValidEmergencyEvent('user_a'));

    await assertFails(
      userADb.collection('emergency_events').doc('event_a1').set({ status: 'resolved' }, { merge: true })
    );
  });

  test('Emergency events CANNOT be deleted by clients', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    await userADb.collection('emergency_events').doc('event_a1').set(getValidEmergencyEvent('user_a'));

    await assertFails(userADb.collection('emergency_events').doc('event_a1').delete());
  });

  // --------------------------------------------------------------------------
  // 5. SCHEMA VALIDATION & UNEXPECTED FIELDS
  // --------------------------------------------------------------------------
  test('Trips with unexpected keys are REJECTED', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    const invalidTrip = {
      ...getValidTrip('user_a'),
      hackedField: 'malicious_data',
    };

    await assertFails(userADb.collection('trips').doc('trip_bad').set(invalidTrip));
  });

  test('Emergency events with invalid coordinates are REJECTED', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    const invalidEvent = {
      ...getValidEmergencyEvent('user_a'),
      latitude: 999.0, // Invalid latitude > 90.0
    };

    await assertFails(userADb.collection('emergency_events').doc('event_bad').set(invalidEvent));
  });

  // --------------------------------------------------------------------------
  // 6. QUERY SCOPING & COLLECTION READS
  // --------------------------------------------------------------------------
  test('User A CAN query trips filtered by their own userId', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    await userADb.collection('trips').doc('trip_a1').set(getValidTrip('user_a'));

    const query = userADb.collection('trips').where('userId', '==', 'user_a');
    await assertSucceeds(query.get());
  });

  test('User A CANNOT query all trips without userId equality filter', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    await userADb.collection('trips').doc('trip_a1').set(getValidTrip('user_a'));

    const globalQuery = userADb.collection('trips');
    await assertFails(globalQuery.get());
  });

  // --------------------------------------------------------------------------
  // 7. DELETION VERIFICATIONS
  // --------------------------------------------------------------------------
  const valid36CharRefId = 'REF-3F05B702050BEC13FC1A73CBC55A3CE0';

  function getValidDeletionVerification(userId, refId = valid36CharRefId) {
    const createdAt = new Date();
    const expiresAt = new Date(createdAt.getTime() + 24 * 60 * 60 * 1000); // Exactly 24 hours
    return {
      userId: userId,
      referenceId: refId,
      createdAt: createdAt,
      expiresAt: expiresAt,
      status: 'pending',
    };
  }

  test('User A CAN create and read their own valid deletion verification reference', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    const refDoc = userADb.collection('deletion_verifications').doc(valid36CharRefId);

    await assertSucceeds(refDoc.set(getValidDeletionVerification('user_a', valid36CharRefId)));
    await assertSucceeds(refDoc.get());
  });

  test('Short, non-hex, or malformed reference IDs are REJECTED', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();

    // Short ID
    await assertFails(
      userADb.collection('deletion_verifications').doc('REF-SHORT').set(getValidDeletionVerification('user_a', 'REF-SHORT'))
    );
    // Lowercase or invalid char
    const invalidCharId = 'REF-3f05b702050bec13fc1a73cbc55a3ce0';
    await assertFails(
      userADb.collection('deletion_verifications').doc(invalidCharId).set(getValidDeletionVerification('user_a', invalidCharId))
    );
    // Wrong prefix
    const wrongPrefixId = 'ABC-3F05B702050BEC13FC1A73CBC55A3CE0';
    await assertFails(
      userADb.collection('deletion_verifications').doc(wrongPrefixId).set(getValidDeletionVerification('user_a', wrongPrefixId))
    );
  });

  test('Future-dated or backdated createdAt timestamps are REJECTED', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();

    // Backdated createdAt (5 days ago)
    const backdatedCreatedAt = new Date(Date.now() - 5 * 24 * 60 * 60 * 1000);
    const backdatedRef = {
      userId: 'user_a',
      referenceId: valid36CharRefId,
      createdAt: backdatedCreatedAt,
      expiresAt: new Date(backdatedCreatedAt.getTime() + 24 * 60 * 60 * 1000),
      status: 'pending',
    };
    await assertFails(userADb.collection('deletion_verifications').doc(valid36CharRefId).set(backdatedRef));

    // Future-dated createdAt (5 days in future)
    const futureCreatedAt = new Date(Date.now() + 5 * 24 * 60 * 60 * 1000);
    const futureRef = {
      userId: 'user_a',
      referenceId: valid36CharRefId,
      createdAt: futureCreatedAt,
      expiresAt: new Date(futureCreatedAt.getTime() + 24 * 60 * 60 * 1000),
      status: 'pending',
    };
    await assertFails(userADb.collection('deletion_verifications').doc(valid36CharRefId).set(futureRef));
  });

  test('Excessive or invalid expiration periods are REJECTED', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    const createdAt = new Date();
    const excessiveExpiresAt = new Date(createdAt.getTime() + 48 * 60 * 60 * 1000); // 48 hours!

    const invalidRef = {
      userId: 'user_a',
      referenceId: valid36CharRefId,
      createdAt: createdAt,
      expiresAt: excessiveExpiresAt,
      status: 'pending',
    };

    await assertFails(userADb.collection('deletion_verifications').doc(valid36CharRefId).set(invalidRef));
  });

  test('Unauthenticated users CANNOT create or read deletion verification references', async () => {
    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(unauthDb.collection('deletion_verifications').doc(valid36CharRefId).get());
    await assertFails(
      unauthDb.collection('deletion_verifications').doc(valid36CharRefId).set(getValidDeletionVerification('user_a'))
    );
  });

  test('User B CANNOT create a deletion verification reference claiming User A\'s userId', async () => {
    const userBDb = testEnv.authenticatedContext('user_b').firestore();
    const spoofedRef = getValidDeletionVerification('user_a');

    await assertFails(userBDb.collection('deletion_verifications').doc(valid36CharRefId).set(spoofedRef));
  });

  test('User B CANNOT read User A\'s deletion verification reference', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    await userADb.collection('deletion_verifications').doc(valid36CharRefId).set(getValidDeletionVerification('user_a'));

    const userBDb = testEnv.authenticatedContext('user_b').firestore();
    await assertFails(userBDb.collection('deletion_verifications').doc(valid36CharRefId).get());
  });

  test('Deletion verification references missing required fields or containing extra fields are REJECTED', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    // Extra field
    const extraFieldRef = {
      ...getValidDeletionVerification('user_a'),
      hackedStatus: 'approved',
    };
    await assertFails(userADb.collection('deletion_verifications').doc(valid36CharRefId).set(extraFieldRef));

    // Missing required field (status)
    const missingFieldRef = {
      userId: 'user_a',
      referenceId: valid36CharRefId,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
    };
    await assertFails(userADb.collection('deletion_verifications').doc(valid36CharRefId).set(missingFieldRef));
  });

  test('Clients CANNOT update or delete deletion verification references', async () => {
    const userADb = testEnv.authenticatedContext('user_a').firestore();
    const refDoc = userADb.collection('deletion_verifications').doc(valid36CharRefId);
    await refDoc.set(getValidDeletionVerification('user_a'));

    // Client attempts to self-approve or complete request
    await assertFails(refDoc.set({ status: 'approved' }, { merge: true }));
    // Client attempts to delete document
    await assertFails(refDoc.delete());
  });
});
