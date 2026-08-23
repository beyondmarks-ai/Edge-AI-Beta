import assert from 'node:assert/strict';
import test from 'node:test';

process.env.TABLE_NAME = 'test';
process.env.REKOGNITION_COLLECTION_ID = 'test';

const {
  buildAssistantContext,
  buildConversationMemory,
  chunkDocumentLines,
  deriveEvent,
  identityFromEvent,
  resolveZone,
  switchPose,
} = await import('../src/handler.mjs');

test('first sighting arrives and marks present', () => {
  assert.deepEqual(deriveEvent(undefined, 'ENTRANCE'), {
    type: 'ARRIVED',
    status: 'PRESENT',
    label: 'Attendance marked present',
  });
});

test('left student returns', () => {
  assert.equal(deriveEvent({ status: 'LEFT', zone: 'EXIT' }, 'ENTRANCE').type, 'RETURNED');
});

test('zone change creates movement event', () => {
  assert.equal(deriveEvent({ status: 'PRESENT', zone: 'LEFT ROW' }, 'CENTER ROW').type, 'MOVED');
});

test('unchanged sighting creates no timeline event', () => {
  assert.equal(deriveEvent({ status: 'PRESENT', zone: 'LEFT ROW' }, 'LEFT ROW'), null);
});

test('exit-zone sighting marks a present student left', () => {
  assert.equal(deriveEvent({ status: 'PRESENT', zone: 'CLASSROOM' }, 'EXIT').type, 'LEFT');
});

test('automatic zone uses the face center position', () => {
  assert.equal(resolveZone('AUTO', { BoundingBox: { Left: 0.05, Width: 0.2 } }), 'LEFT AREA');
  assert.equal(resolveZone('AUTO', { BoundingBox: { Left: 0.4, Width: 0.2 } }), 'CENTER AREA');
  assert.equal(resolveZone('AUTO', { BoundingBox: { Left: 0.8, Width: 0.1 } }), 'RIGHT AREA');
});

test('a configured camera zone overrides frame position', () => {
  assert.equal(resolveZone('EXIT', { BoundingBox: { Left: 0.1, Width: 0.1 } }), 'EXIT');
});

test('administrator role is read from Cognito groups', () => {
  const identity = identityFromEvent({
    requestContext: { authorizer: { jwt: { claims: { sub: 'abc', email: 'staff@example.com', 'cognito:groups': '[admins]' } } } },
  });
  assert.deepEqual(identity, { sub: 'abc', email: 'staff@example.com', isAdmin: true });
});

test('student identity is not elevated without the admin group', () => {
  const identity = identityFromEvent({
    requestContext: { authorizer: { jwt: { claims: { sub: 'student-1', email: 'student@example.com' } } } },
  });
  assert.equal(identity.isAdmin, false);
});

test('guided pose feedback accepts the expected angles', () => {
  assert.equal(switchPose('FRONT', 2, -1).accepted, true);
  assert.equal(switchPose('LEFT', -18, 0).accepted, true);
  assert.equal(switchPose('RIGHT', 18, 0).accepted, true);
  assert.equal(switchPose('UP', 0, 10).accepted, true);
  assert.equal(switchPose('DOWN', 0, -10).accepted, true);
});

test('assistant context keeps only the newest visual observation per student', () => {
  const context = buildAssistantContext(
    { students: [{ studentId: 's1', name: 'Rakesh', zone: 'CENTER AREA' }] },
    [
      {
        studentId: 's1',
        timestamp: '2026-08-23T10:05:00.000Z',
        label: 'Wearing a blue shirt.',
        visualContext: { clothing: ['blue shirt'], carriedObjects: ['book'] },
      },
      {
        studentId: 's1',
        timestamp: '2026-08-23T10:00:00.000Z',
        label: 'Older observation.',
        visualContext: { clothing: ['red shirt'] },
      },
    ],
  );
  assert.equal(context.latestVisualContext.length, 1);
  assert.equal(context.latestVisualContext[0].name, 'Rakesh');
  assert.deepEqual(context.latestVisualContext[0].clothing, ['blue shirt']);
});

test('assistant memory keeps the latest 20 messages and normalizes roles', () => {
  const messages = Array.from({ length: 24 }, (_, index) => ({
    role: index % 2 ? 'ASSISTANT' : 'USER',
    text: `message-${index}`,
    timestamp: `2026-08-23T10:${String(index).padStart(2, '0')}:00.000Z`,
  }));
  const memory = buildConversationMemory(messages);
  assert.equal(memory.length, 20);
  assert.equal(memory[0].text, 'message-4');
  assert.equal(memory.at(-1).text, 'message-23');
  assert.equal(memory.at(-1).role, 'ASSISTANT');
});

test('document text is split into bounded overlapping RAG chunks', () => {
  const chunks = chunkDocumentLines([
    { page: 1, text: 'A'.repeat(700) },
    { page: 1, text: 'B'.repeat(700) },
    { page: 2, text: 'C'.repeat(300) },
  ]);
  assert.equal(chunks.length, 2);
  assert.ok(chunks.every((chunk) => chunk.text.length <= 1200));
  assert.match(chunks[1].text, /^A+\nB+/);
  assert.equal(chunks[1].page, 2);
});
