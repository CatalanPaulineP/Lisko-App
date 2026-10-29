const admin = require('firebase-admin');
const {
  validateEmulatorEnvironment,
  parseArgs,
  parseTimestampSafely,
  isTripEligibleForDeletion,
  isEmergencyEventEligibleForDeletion,
  runCleanup,
  TERMINAL_STATUS_ALLOWLIST,
  EXPECTED_PROJECT_ID,
  PROD_PROJECT_ID
} = require('../scripts/cleanup_firestore_emulator');

// Ensure firebase-admin is initialized for local emulator tests
const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
process.env.GCLOUD_PROJECT = EXPECTED_PROJECT_ID;

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: EXPECTED_PROJECT_ID });
}

const db = admin.firestore();

jest.setTimeout(30000);

describe('LisKo Safe Spark-Compatible Cleanup Tool Emulator Tests', () => {
  const now = new Date('2026-03-30T12:00:00.000Z');
  const dayMs = 24 * 60 * 60 * 1000;

  beforeEach(async () => {
    // Clear trips and emergency_events collections before each test
    const trips = await db.collection('trips').get();
    for (const doc of trips.docs) {
      await doc.ref.delete();
    }
    const emergencies = await db.collection('emergency_events').get();
    for (const doc of emergencies.docs) {
      await doc.ref.delete();
    }
  });

  // --------------------------------------------------------------------------
  // Safeguard & Validation Tests
  // --------------------------------------------------------------------------
  test('11 & 12 & 13: Environment validation enforces loopback host and expected project ID, rejecting production', () => {
    // Missing host
    expect(() => validateEmulatorEnvironment({ emulatorHost: '', projectId: EXPECTED_PROJECT_ID }))
      .toThrow('FIRESTORE_EMULATOR_HOST is not set');

    // Non-loopback host
    expect(() => validateEmulatorEnvironment({ emulatorHost: '192.168.1.50:8080', projectId: EXPECTED_PROJECT_ID }))
      .toThrow('Non-loopback emulator host detected');

    // Production project ID rejected
    expect(() => validateEmulatorEnvironment({ emulatorHost: '127.0.0.1:8080', projectId: PROD_PROJECT_ID }))
      .toThrow(`Production project ID (${PROD_PROJECT_ID}) rejected!`);

    // Unexpected project ID
    expect(() => validateEmulatorEnvironment({ emulatorHost: '127.0.0.1:8080', projectId: 'some-other-project' }))
      .toThrow('Unexpected project ID');

    // Valid emulator environment
    const valid = validateEmulatorEnvironment({ emulatorHost: '127.0.0.1:8080', projectId: EXPECTED_PROJECT_ID });
    expect(valid.projectId).toBe(EXPECTED_PROJECT_ID);
  });

  test('14 & 15: Argument parsing defaults to dry-run unless both --commit and --confirm-emulator-deletion are passed', () => {
    expect(parseArgs([]).dryRun).toBe(true);
    expect(parseArgs(['--commit']).dryRun).toBe(true);
    expect(parseArgs(['--confirm-emulator-deletion']).dryRun).toBe(true);

    const commitFlags = parseArgs(['--commit', '--confirm-emulator-deletion']);
    expect(commitFlags.dryRun).toBe(false);
    expect(commitFlags.isCommit).toBe(true);
    expect(commitFlags.isConfirmed).toBe(true);
  });

  test('10: Missing or invalid timestamps are safely skipped without throwing', () => {
    const cutoff30 = new Date(now.getTime() - 30 * dayMs);

    expect(isTripEligibleForDeletion({ status: 'arrived', startedAt: null }, cutoff30).eligible).toBe(false);
    expect(isTripEligibleForDeletion({ status: 'arrived', startedAt: 'invalid-date' }, cutoff30).eligible).toBe(false);
    expect(isEmergencyEventEligibleForDeletion({ triggeredAt: null }, cutoff30).eligible).toBe(false);
  });

  // --------------------------------------------------------------------------
  // Trip Retention & Status Eligibility Tests
  // --------------------------------------------------------------------------
  test('1: Recent completed trip (<30 days old) is preserved', () => {
    const cutoff30 = new Date(now.getTime() - 30 * dayMs);
    const recentDate = new Date(now.getTime() - 10 * dayMs); // 10 days old

    const result = isTripEligibleForDeletion({ status: 'arrived', completedAt: recentDate }, cutoff30);
    expect(result.eligible).toBe(false);
  });

  test('2: Completed trip older than 30 days is eligible for deletion', () => {
    const cutoff30 = new Date(now.getTime() - 30 * dayMs);
    const oldDate = new Date(now.getTime() - 40 * dayMs); // 40 days old

    const result = isTripEligibleForDeletion({ status: 'arrived', completedAt: oldDate }, cutoff30);
    expect(result.eligible).toBe(true);
  });

  test('3: Active trip older than 30 days is PRESERVED (non-terminal status)', () => {
    const cutoff30 = new Date(now.getTime() - 30 * dayMs);
    const oldDate = new Date(now.getTime() - 40 * dayMs);

    const result = isTripEligibleForDeletion({ status: 'active', startedAt: oldDate }, cutoff30);
    expect(result.eligible).toBe(false);
  });

  test('4: Timeout warning trip older than 30 days is PRESERVED', () => {
    const cutoff30 = new Date(now.getTime() - 30 * dayMs);
    const oldDate = new Date(now.getTime() - 40 * dayMs);

    const result = isTripEligibleForDeletion({ status: 'timeout_warning', startedAt: oldDate }, cutoff30);
    expect(result.eligible).toBe(false);
  });

  test('5: Unknown or null status trip older than 30 days is PRESERVED', () => {
    const cutoff30 = new Date(now.getTime() - 30 * dayMs);
    const oldDate = new Date(now.getTime() - 40 * dayMs);

    expect(isTripEligibleForDeletion({ status: 'unknown_status', startedAt: oldDate }, cutoff30).eligible).toBe(false);
    expect(isTripEligibleForDeletion({ status: null, startedAt: oldDate }, cutoff30).eligible).toBe(false);
  });

  test('6: Extended trip that reached terminal status (arrived/help_requested) follows 30-day policy', () => {
    const cutoff30 = new Date(now.getTime() - 30 * dayMs);
    const oldDate = new Date(now.getTime() - 40 * dayMs);

    const result = isTripEligibleForDeletion({
      status: 'arrived',
      wasExtended: true,
      completedAt: oldDate
    }, cutoff30);

    expect(result.eligible).toBe(true);
  });

  test('7: Extended trip that is still active ("Trip Extended" or "extended") is PRESERVED', () => {
    const cutoff30 = new Date(now.getTime() - 30 * dayMs);
    const oldDate = new Date(now.getTime() - 40 * dayMs);

    expect(isTripEligibleForDeletion({ status: 'Trip Extended', wasExtended: true, startedAt: oldDate }, cutoff30).eligible).toBe(false);
    expect(isTripEligibleForDeletion({ status: 'extended', wasExtended: true, startedAt: oldDate }, cutoff30).eligible).toBe(false);
  });

  // --------------------------------------------------------------------------
  // Emergency Events Retention Tests (90-Day Policy)
  // --------------------------------------------------------------------------
  test('8: Emergency event younger than 90 days is PRESERVED', () => {
    const cutoff90 = new Date(now.getTime() - 90 * dayMs);
    const recentEmergency = new Date(now.getTime() - 45 * dayMs); // 45 days old

    const result = isEmergencyEventEligibleForDeletion({ triggeredAt: recentEmergency }, cutoff90);
    expect(result.eligible).toBe(false);
  });

  test('9: Emergency event older than 90 days is ELIGIBLE for deletion', () => {
    const cutoff90 = new Date(now.getTime() - 90 * dayMs);
    const oldEmergency = new Date(now.getTime() - 100 * dayMs); // 100 days old

    const result = isEmergencyEventEligibleForDeletion({ triggeredAt: oldEmergency }, cutoff90);
    expect(result.eligible).toBe(true);
  });

  // --------------------------------------------------------------------------
  // Full Emulator Run & Dry-Run vs Commit Verification
  // --------------------------------------------------------------------------
  test('14: Default dry-run evaluates documents but performs ZERO deletions in emulator', async () => {
    const oldDate = new Date(now.getTime() - 40 * dayMs);

    // Seed 1 eligible trip and 1 preserved active trip
    await db.collection('trips').doc('trip_eligible_1').set({
      userId: 'user_1',
      destination: 'Campus',
      status: 'arrived',
      completedAt: admin.firestore.Timestamp.fromDate(oldDate)
    });

    await db.collection('trips').doc('trip_active_1').set({
      userId: 'user_1',
      destination: 'Home',
      status: 'active',
      startedAt: admin.firestore.Timestamp.fromDate(oldDate)
    });

    const envOverride = { emulatorHost: EMULATOR_HOST, projectId: EXPECTED_PROJECT_ID };
    const results = await runCleanup(db, {
      envOverride,
      args: [], // Default dry-run
      now
    });

    expect(results.dryRun).toBe(true);
    expect(results.tripsEvaluated).toBe(2);
    expect(results.tripsEligible).toBe(1);
    expect(results.tripsDeleted).toBe(0); // ZERO DELETIONS IN DRY-RUN

    // Verify documents still exist in emulator
    const trip1 = await db.collection('trips').doc('trip_eligible_1').get();
    expect(trip1.exists).toBe(true);
  });

  test('15: Authorized commit mode (--commit and --confirm-emulator-deletion) deletes only eligible documents in emulator', async () => {
    const oldTripDate = new Date(now.getTime() - 40 * dayMs);
    const recentTripDate = new Date(now.getTime() - 10 * dayMs);
    const oldEmergencyDate = new Date(now.getTime() - 100 * dayMs);
    const recentEmergencyDate = new Date(now.getTime() - 45 * dayMs);

    // Seed Trips
    await db.collection('trips').doc('trip_old_arrived').set({
      status: 'arrived',
      completedAt: admin.firestore.Timestamp.fromDate(oldTripDate)
    });
    await db.collection('trips').doc('trip_recent_arrived').set({
      status: 'arrived',
      completedAt: admin.firestore.Timestamp.fromDate(recentTripDate)
    });
    await db.collection('trips').doc('trip_old_active').set({
      status: 'active',
      startedAt: admin.firestore.Timestamp.fromDate(oldTripDate)
    });

    // Seed Emergency Events
    await db.collection('emergency_events').doc('emergency_old').set({
      triggeredAt: admin.firestore.Timestamp.fromDate(oldEmergencyDate)
    });
    await db.collection('emergency_events').doc('emergency_recent').set({
      triggeredAt: admin.firestore.Timestamp.fromDate(recentEmergencyDate)
    });

    const envOverride = { emulatorHost: EMULATOR_HOST, projectId: EXPECTED_PROJECT_ID };
    const results = await runCleanup(db, {
      envOverride,
      args: ['--commit', '--confirm-emulator-deletion'],
      now
    });

    expect(results.dryRun).toBe(false);
    expect(results.tripsEligible).toBe(1);
    expect(results.tripsDeleted).toBe(1);
    expect(results.emergenciesEligible).toBe(1);
    expect(results.emergenciesDeleted).toBe(1);

    // Verify exactly eligible documents were deleted, preserved documents remain
    expect((await db.collection('trips').doc('trip_old_arrived').get()).exists).toBe(false);
    expect((await db.collection('trips').doc('trip_recent_arrived').get()).exists).toBe(true);
    expect((await db.collection('trips').doc('trip_old_active').get()).exists).toBe(true);

    expect((await db.collection('emergency_events').doc('emergency_old').get()).exists).toBe(false);
    expect((await db.collection('emergency_events').doc('emergency_recent').get()).exists).toBe(true);
  });
});
