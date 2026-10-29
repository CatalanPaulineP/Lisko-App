/**
 * LisKo Mobile Safety Application — Secure Administrator Data Deletion Emulator Test Suite
 * File: test_rules/admin_deletion.test.js
 *
 * EMULATOR-ONLY TEST SUITE FOR PHASE 5E.2.
 */

const admin = require('firebase-admin');
const path = require('path');
const {
  initAdminEnvironment,
  processAdminDeletionRequest,
  assertLockOwnership,
} = require('../scripts/admin_data_deletion');

const EXPECTED_PROJECT_ID = 'demo-lisko-admin-deletion';
const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const AUTH_EMULATOR_HOST =
  process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';

process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
process.env.FIREBASE_AUTH_EMULATOR_HOST = AUTH_EMULATOR_HOST;
process.env.GCLOUD_PROJECT = EXPECTED_PROJECT_ID;

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: EXPECTED_PROJECT_ID });
}

const db = admin.firestore();
const auth = admin.auth();

jest.setTimeout(30000);

describe('LisKo Secure Administrator Data Deletion Emulator Tests', () => {
  const validRefId = 'REF-3F05B702050BEC13FC1A73CBC55A3CE0';
  const targetUid = 'user_target_123';
  const otherUid = 'user_other_456';

  beforeEach(async () => {
    // Clear test collections before each test
    const collections = ['trips', 'emergency_events', 'deletion_verifications', 'deletion_locks'];
    for (const colName of collections) {
      const snap = await db.collection(colName).get();
      const batch = db.batch();
      snap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }

    // Delete test users from Auth emulator if existing
    try {
      await auth.deleteUser(targetUid);
    } catch (e) {}
    try {
      await auth.deleteUser(otherUid);
    } catch (e) {}
  });

  // Helper to create a valid deletion verification document
  async function createTestReference(refId, userId, overrides = {}) {
    const createdAt = new Date();
    const expiresAt = new Date(createdAt.getTime() + 24 * 60 * 60 * 1000);
    const refData = {
      userId,
      referenceId: refId,
      createdAt,
      expiresAt,
      status: 'pending',
      ...overrides,
    };
    await db.collection('deletion_verifications').doc(refId).set(refData);

    if (refData.status === 'processing') {
      await db.collection('deletion_locks').doc(userId).set({
        userId,
        lockedByRef: refId,
        executionId: refData.executionId || 'EXEC-TEST-PROCESSING',
        status: 'processing',
        lockedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return refData;
  }

  // 1. Valid reference format accepted
  test('1. Valid reference format accepted', async () => {
    await createTestReference(validRefId, targetUid);
    const result = await processAdminDeletionRequest({
      refId: validRefId,
      execute: false,
      projectId: EXPECTED_PROJECT_ID,
    });
    expect(result.success).toBe(true);
    expect(result.preview.targetUid).toBe(targetUid);
  });

  // 2. Invalid reference format rejected
  test('2. Invalid reference format rejected', async () => {
    await expect(
      processAdminDeletionRequest({
        refId: 'REF-SHORT',
        execute: false,
        projectId: EXPECTED_PROJECT_ID,
      })
    ).rejects.toThrow('Invalid reference ID format');
  });

  // 3. Expired reference rejected
  test('3. Expired reference rejected', async () => {
    const pastExpires = new Date(Date.now() - 3600000); // 1 hour ago
    await createTestReference(validRefId, targetUid, { expiresAt: pastExpires });

    await expect(
      processAdminDeletionRequest({
        refId: validRefId,
        execute: false,
        projectId: EXPECTED_PROJECT_ID,
      })
    ).rejects.toThrow('expired at');
  });

  // 4. Missing reference rejected
  test('4. Missing reference rejected', async () => {
    await expect(
      processAdminDeletionRequest({
        refId: validRefId,
        execute: false,
        projectId: EXPECTED_PROJECT_ID,
      })
    ).rejects.toThrow('does not exist');
  });

  // 5. Default dry-run does not change records
  test('5. Default dry-run does not change records', async () => {
    await createTestReference(validRefId, targetUid);
    await db.collection('trips').doc('trip_1').set({
      userId: targetUid,
      installationId: 'inst_1',
      destination: 'Campus',
      estimatedTravelMinutes: 20,
      startedAt: new Date(),
      status: 'arrived',
    });

    const result = await processAdminDeletionRequest({
      refId: validRefId,
      execute: false,
      projectId: EXPECTED_PROJECT_ID,
    });

    expect(result.mode).toBe('DRY_RUN');
    expect(result.preview.matchedTripsCount).toBe(1);

    // Verify trip document was NOT deleted
    const tripSnap = await db.collection('trips').doc('trip_1').get();
    expect(tripSnap.exists).toBe(true);
  });

  // 6. Matching UID records correctly identified
  test('6. Matching UID records correctly identified', async () => {
    await createTestReference(validRefId, targetUid);
    await db.collection('trips').doc('trip_1').set({
      userId: targetUid,
      installationId: 'inst_1',
      destination: 'Campus',
      estimatedTravelMinutes: 20,
      startedAt: new Date(),
      status: 'arrived',
    });
    await db.collection('emergency_events').doc('event_1').set({
      userId: targetUid,
      installationId: 'inst_1',
      deviceId: 'dev_1',
      tripId: 'trip_1',
      latitude: 14.5,
      longitude: 120.9,
      emergencyType: 'SOS',
      triggeredAt: new Date(),
      status: 'active',
    });

    const result = await processAdminDeletionRequest({
      refId: validRefId,
      execute: false,
      projectId: EXPECTED_PROJECT_ID,
    });

    expect(result.preview.matchedTripsCount).toBe(1);
    expect(result.preview.matchedEmergencyCount).toBe(1);
  });

  // 7. Other users' records remain untouched
  test('7. Other users\' records remain untouched', async () => {
    await createTestReference(validRefId, targetUid);
    // Target user trip
    await db.collection('trips').doc('trip_target').set({
      userId: targetUid,
      installationId: 'inst_1',
      destination: 'Campus',
      estimatedTravelMinutes: 20,
      startedAt: new Date(),
      status: 'arrived',
    });
    // Other user trip
    await db.collection('trips').doc('trip_other').set({
      userId: otherUid,
      installationId: 'inst_2',
      destination: 'Home',
      estimatedTravelMinutes: 15,
      startedAt: new Date(),
      status: 'arrived',
    });

    await processAdminDeletionRequest({
      refId: validRefId,
      execute: true,
      confirmDelete: true,
      projectId: EXPECTED_PROJECT_ID,
    });

    // Target trip deleted
    const targetSnap = await db.collection('trips').doc('trip_target').get();
    expect(targetSnap.exists).toBe(false);

    // Other trip UNTOUCHED
    const otherSnap = await db.collection('trips').doc('trip_other').get();
    expect(otherSnap.exists).toBe(true);
  });

  // 8. Active trips block destructive deletion
  test('8. Active trips block destructive deletion', async () => {
    await createTestReference(validRefId, targetUid);
    await db.collection('trips').doc('trip_active').set({
      userId: targetUid,
      installationId: 'inst_1',
      destination: 'Campus',
      estimatedTravelMinutes: 20,
      startedAt: new Date(),
      status: 'active', // Active trip ongoing!
    });

    await expect(
      processAdminDeletionRequest({
        refId: validRefId,
        execute: true,
        confirmDelete: true,
        projectId: EXPECTED_PROJECT_ID,
      })
    ).rejects.toThrow('Active trip detected');
  });

  // 9. Multiple references for same UID cannot process concurrently (UID locking)
  test('9. Multiple references for the same UID cannot process concurrently', async () => {
    const ref2Id = 'REF-4F05B702050BEC13FC1A73CBC55A3CE1';
    await createTestReference(validRefId, targetUid, { status: 'processing' });
    await createTestReference(ref2Id, targetUid, { status: 'pending' });

    await expect(
      processAdminDeletionRequest({
        refId: ref2Id,
        execute: false,
        projectId: EXPECTED_PROJECT_ID,
      })
    ).rejects.toThrow('Atomic UID lock active');
  });

  // 10. Concurrent administrators cannot both claim deletion
  test('10. Concurrent administrators cannot both claim deletion', async () => {
    await createTestReference(validRefId, targetUid);

    // First admin claims reference
    const p1 = processAdminDeletionRequest({
      refId: validRefId,
      execute: true,
      confirmDelete: true,
      projectId: EXPECTED_PROJECT_ID,
    });

    // Second admin tries concurrently
    const p2 = processAdminDeletionRequest({
      refId: validRefId,
      execute: true,
      confirmDelete: true,
      projectId: EXPECTED_PROJECT_ID,
    });

    const results = await Promise.allSettled([p1, p2]);
    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    const rejected = results.filter((r) => r.status === 'rejected');

    expect(fulfilled.length).toBe(1);
    expect(rejected.length).toBe(1);
  });

  // 11. Partial deletion failure supports safe retry (idempotency)
  test('11. Partial deletion failure supports safe retry', async () => {
    // Reference marked as 'processing' from an interrupted run
    await createTestReference(validRefId, targetUid, { status: 'processing' });
    await db.collection('trips').doc('trip_part').set({
      userId: targetUid,
      installationId: 'inst_1',
      destination: 'Campus',
      estimatedTravelMinutes: 20,
      startedAt: new Date(),
      status: 'arrived',
    });

    const result = await processAdminDeletionRequest({
      refId: validRefId,
      execute: true,
      confirmDelete: true,
      projectId: EXPECTED_PROJECT_ID,
    });

    expect(result.summary.finalRefStatus).toBe('completed');
    expect(result.summary.deletedTripsCount).toBe(1);
  });

  // 12. Already completed reference cannot be processed again
  test('12. Already completed reference cannot be processed again', async () => {
    await createTestReference(validRefId, targetUid, { status: 'completed' });

    await expect(
      processAdminDeletionRequest({
        refId: validRefId,
        execute: false,
        projectId: EXPECTED_PROJECT_ID,
      })
    ).rejects.toThrow('has already been processed');
  });

  // 13. Auth Emulator account deletion works correctly
  test('13. Auth Emulator account deletion works correctly', async () => {
    await auth.createUser({ uid: targetUid });
    await createTestReference(validRefId, targetUid);

    const result = await processAdminDeletionRequest({
      refId: validRefId,
      execute: true,
      confirmDelete: true,
      projectId: EXPECTED_PROJECT_ID,
    });

    expect(result.summary.authUserDeleted).toBe(true);

    // Verify user no longer exists in Auth emulator
    await expect(auth.getUser(targetUid)).rejects.toThrow();
  });

  // 14. Reference completion records are handled correctly
  test('14. Reference completion records are handled correctly', async () => {
    await createTestReference(validRefId, targetUid);

    await processAdminDeletionRequest({
      refId: validRefId,
      execute: true,
      confirmDelete: true,
      projectId: EXPECTED_PROJECT_ID,
    });

    const refSnap = await db
      .collection('deletion_verifications')
      .doc(validRefId)
      .get();
    expect(refSnap.data().status).toBe('completed');
    expect(refSnap.data().completedAt).toBeDefined();
  });

  // 15. Production project IDs are rejected
  test('15. Production project IDs are rejected', async () => {
    await expect(
      processAdminDeletionRequest({
        refId: validRefId,
        execute: false,
        projectId: 'lisko-25162', // Production ID!
      })
    ).rejects.toThrow('Production project ID lisko-25162 strictly prohibited');
  });

  // 16. Missing emulator environment variables are rejected
  test('16. Missing emulator environment variables are rejected', async () => {
    const origFirestore = process.env.FIRESTORE_EMULATOR_HOST;
    delete process.env.FIRESTORE_EMULATOR_HOST;

    try {
      expect(() =>
        initAdminEnvironment(EXPECTED_PROJECT_ID)
      ).toThrow('Missing emulator host env variables');
    } finally {
      process.env.FIRESTORE_EMULATOR_HOST = origFirestore;
    }
  });

  // 17. Non-loopback emulator connections are rejected
  test('17. Non-loopback emulator connections are rejected', async () => {
    const origFirestore = process.env.FIRESTORE_EMULATOR_HOST;
    process.env.FIRESTORE_EMULATOR_HOST = '192.168.1.100:8080';

    try {
      expect(() =>
        initAdminEnvironment(EXPECTED_PROJECT_ID)
      ).toThrow('Non-loopback host rejected');
    } finally {
      process.env.FIRESTORE_EMULATOR_HOST = origFirestore;
    }
  });

  // 18. Simultaneous executions with DIFFERENT reference IDs for SAME UID are atomically locked
  test('18. Simultaneous executions with DIFFERENT reference IDs for SAME UID are atomically locked', async () => {
    const ref1Id = 'REF-3F05B702050BEC13FC1A73CBC55A3CE0';
    const ref2Id = 'REF-4F05B702050BEC13FC1A73CBC55A3CE1';

    await createTestReference(ref1Id, targetUid);
    await createTestReference(ref2Id, targetUid);

    // Admin 1 starts ref1 with executionId_1
    const p1 = processAdminDeletionRequest({
      refId: ref1Id,
      execute: true,
      confirmDelete: true,
      projectId: EXPECTED_PROJECT_ID,
      executionId: 'EXEC-ADMIN-1-1001',
    });

    // Admin 2 starts ref2 with executionId_2 concurrently
    const p2 = processAdminDeletionRequest({
      refId: ref2Id,
      execute: true,
      confirmDelete: true,
      projectId: EXPECTED_PROJECT_ID,
      executionId: 'EXEC-ADMIN-2-1002',
    });

    const results = await Promise.allSettled([p1, p2]);
    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    const rejected = results.filter((r) => r.status === 'rejected');

    // Exactly one admin succeeds, and one admin is rejected by lock or auto-completion
    expect(fulfilled.length).toBe(1);
    expect(rejected.length).toBe(1);
    expect(rejected[0].reason.message).toMatch(/Atomic UID lock active|already been completed/);
  });

  // 19. Abandoned lock (>5 mins old) requires forceRecovery: true to reclaim
  test('19. Abandoned lock (>5 mins old) requires forceRecovery: true to reclaim', async () => {
    const abandonedLockTime = new Date(Date.now() - 10 * 60 * 1000); // 10 mins ago
    await createTestReference(validRefId, targetUid, { status: 'processing' });

    // Set abandoned lock in /deletion_locks/
    await db.collection('deletion_locks').doc(targetUid).set({
      userId: targetUid,
      lockedByRef: 'REF-OLD-ABANDONED',
      executionId: 'EXEC-OLD-DEAD',
      status: 'processing',
      lockedAt: abandonedLockTime,
    });

    // Reclaim attempt without forceRecovery is REJECTED
    await expect(
      processAdminDeletionRequest({
        refId: validRefId,
        execute: true,
        confirmDelete: true,
        forceRecovery: false,
        projectId: EXPECTED_PROJECT_ID,
        executionId: 'EXEC-FRESH-RECOVERY',
      })
    ).rejects.toThrow('exceeded lease timeout');

    // Reclaim attempt WITH forceRecovery SUCCEEDS
    const result = await processAdminDeletionRequest({
      refId: validRefId,
      execute: true,
      confirmDelete: true,
      forceRecovery: true,
      projectId: EXPECTED_PROJECT_ID,
      executionId: 'EXEC-FRESH-RECOVERY',
    });

    expect(result.success).toBe(true);
    expect(result.summary.finalRefStatus).toBe('completed');
  });

  // 20. Executing deletion automatically completes all pending references for target UID
  test('20. Executing deletion automatically completes all pending references for target UID', async () => {
    const ref1Id = 'REF-3F05B702050BEC13FC1A73CBC55A3CE0';
    const ref2Id = 'REF-4F05B702050BEC13FC1A73CBC55A3CE1';

    await createTestReference(ref1Id, targetUid);
    await createTestReference(ref2Id, targetUid);

    const result = await processAdminDeletionRequest({
      refId: ref1Id,
      execute: true,
      confirmDelete: true,
      projectId: EXPECTED_PROJECT_ID,
    });

    expect(result.summary.completedRefsCount).toBe(2);

    // Verify both ref1 and ref2 are marked completed in Firestore
    const ref1Snap = await db.collection('deletion_verifications').doc(ref1Id).get();
    const ref2Snap = await db.collection('deletion_verifications').doc(ref2Id).get();

    expect(ref1Snap.data().status).toBe('completed');
    expect(ref2Snap.data().status).toBe('completed');
  });

  // 21. Stale process whose lock was taken over is IMMEDIATELY ABORTED by assertLockOwnership
  test('21. Stale process whose lock was taken over is IMMEDIATELY ABORTED by assertLockOwnership', async () => {
    // Set lock owned by execution 1
    await db.collection('deletion_locks').doc(targetUid).set({
      userId: targetUid,
      lockedByRef: validRefId,
      executionId: 'EXEC-OLD-STALE-1',
      status: 'processing',
      lockedAt: new Date(),
    });

    // Verify execution 1 currently passes ownership
    await expect(assertLockOwnership(db, targetUid, 'EXEC-OLD-STALE-1')).resolves.not.toThrow();

    // Takeover lock by execution 2
    await db.collection('deletion_locks').doc(targetUid).set({
      userId: targetUid,
      lockedByRef: validRefId,
      executionId: 'EXEC-NEW-TAKEOVER-2',
      status: 'processing',
      lockedAt: new Date(),
    });

    // Verify execution 1 is now IMMEDIATELY REJECTED when asserting ownership
    await expect(assertLockOwnership(db, targetUid, 'EXEC-OLD-STALE-1')).rejects.toThrow(
      'Lock ownership for UID user_target_123 was taken over by execution EXEC-NEW-TAKEOVER-2'
    );
  });
});
