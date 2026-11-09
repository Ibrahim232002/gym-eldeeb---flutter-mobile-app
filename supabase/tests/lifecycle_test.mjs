// Run against an in-memory PostgreSQL runtime, never the production database.
// node supabase/tests/lifecycle_test.mjs <path-to-@electric-sql/pglite>
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const runtime = resolve(process.argv[2] ?? 'node_modules/@electric-sql/pglite');
const { PGlite } = await import(pathToFileURL(resolve(runtime, 'dist/index.js')));
const { btree_gist } = await import(pathToFileURL(resolve(runtime, 'dist/contrib/btree_gist.js')));
const db = new PGlite({ extensions: { btree_gist } });
let passed = 0;
async function check(name, fn) {
  await fn();
  console.log(`PASS ${++passed}: ${name}`);
}
const query = (sql, values) => db.query(sql, values);
const one = async (sql, values) => (await query(sql, values)).rows[0];
const id = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const gymA = id(1), gymB = id(2), actorA = id(3), actorB = id(4);
const date = '2026-11-09';
const member = (n) => one('select * from members where id=$1', [id(n)]);
async function addMember(n, gym = gymA) {
  await query('insert into members(id,gym_id,full_name) values($1,$2,$3)', [id(n), gym, `Fixture ${n}`]);
}
async function addMembership(n, memberId, start = date, end = '2026-12-08', extra = {}) {
  const row = { id: id(n), gym_id: gymA, member_id: id(memberId), start_date: start,
    end_date: end, price: 250, status: 'active', ...extra };
  await query(`insert into memberships(id,gym_id,member_id,start_date,end_date,price,status,deleted_at)
    select id,gym_id,member_id,start_date,end_date,price,status,deleted_at
    from jsonb_populate_record(null::memberships,$1::jsonb)`, [JSON.stringify(row)]);
  return row;
}
function bundle(n, m, start = date, end = '2026-12-08', extraPayment = {}) {
  const membership = { id: id(n), gym_id: gymA, member_id: id(m), start_date: start,
    end_date: end, price: 250, status: 'active', created_by: actorB };
  const payment = { id: id(n + 1000), gym_id: gymA, membership_id: id(n), amount: 250,
    payment_method: 'cash', paid_at: '2026-11-09T12:00:00Z', recorded_by: actorB, ...extraPayment };
  return [JSON.stringify(membership), JSON.stringify(payment)];
}
async function rpc(values) {
  return (await one('select create_membership_with_initial_payment($1::jsonb,$2::jsonb) result', values)).result;
}
async function asActor(actor, fn) {
  await query("select set_config('request.jwt.claim.sub',$1,false)", [actor]);
  await db.exec('set role authenticated');
  try { return await fn(); } finally { await db.exec('reset role'); }
}
async function clock(day) {
  await query('update test_clock set today=$1', [day]);
}
try {
  await db.exec(await readFile(new URL('fixtures/audited_schema.sql', import.meta.url), 'utf8'));
  await query('insert into gyms(id,name) values ($1,\'Test A\'),($2,\'Test B\')', [gymA, gymB]);
  await query('insert into auth.users(id) values($1),($2)', [actorA, actorB]);
  await query("insert into profiles(id,gym_id,full_name) values($1,$2,'Coach A'),($3,$4,'Coach B')", [actorA, gymA, actorB, gymB]);
  const migration = await readFile(new URL('../migrations/20261109001226_membership_lifecycle_cairo.sql', import.meta.url), 'utf8');
  // Hosted cron installation/permissions are verified separately after deployment.
  await db.exec(migration.split('-- CRON INSTALLATION BEGIN')[0]);
  await db.exec(`create table test_clock(today date); insert into test_clock values('${date}');
    grant select on test_clock to authenticated;
    create or replace function gym_private.cairo_today() returns date language sql stable
    set search_path='' as $$ select today from public.test_clock $$;`);

  await check('valid membership stays active through inclusive end date', async () => {
    await addMember(10);
    assert.equal((await member(10)).is_active, false);
    await addMembership(100, 10, '2026-10-11', date);
    assert.equal((await member(10)).is_active, true);
    await db.exec('select gym_private.reconcile_membership_lifecycle()');
    assert.equal((await member(10)).is_active, true);
  });
  await check('following Cairo day expires membership and deactivates member', async () => {
    await clock('2026-11-10');
    await db.exec('select gym_private.reconcile_membership_lifecycle()');
    assert.equal((await member(10)).is_active, false);
    assert.equal((await one('select status from memberships where id=$1', [id(100)])).status, 'expired');
    await clock(date);
  });
  await check('expired history cannot override another current membership', async () => {
    await addMembership(101, 10);
    await db.exec('select gym_private.reconcile_membership_lifecycle()');
    assert.equal((await member(10)).is_active, true);
  });
  await check('expired plus future coverage stays inactive until start day', async () => {
    await addMember(11);
    await addMembership(102, 11, '2026-10-01', '2026-10-30');
    await addMembership(103, 11, '2026-11-10', '2026-12-09');
    assert.equal((await member(11)).is_active, false);
    await clock('2026-11-10');
    await db.exec('select gym_private.reconcile_membership_lifecycle()');
    assert.equal((await member(11)).is_active, true);
    await clock(date);
  });
  await check('inactive member renewal commits activation and payment together', async () => {
    await addMember(12);
    const result = await asActor(actorA, () => rpc(bundle(104, 12)));
    assert.equal(result.member.is_active, true);
    assert.equal(result.membership.created_by, actorA);
    assert.equal(result.payment.recorded_by, actorA);
    assert.equal(result.payment.amount, 250);
  });
  await check('manual deactivation persists until successful renewal', async () => {
    await addMember(13);
    await asActor(actorA, () => query('select set_member_activation($1,false,0)', [id(13)]));
    await db.exec('select gym_private.reconcile_membership_lifecycle()');
    assert.equal((await member(13)).manually_deactivated, true);
    const result = await asActor(actorA, () => rpc(bundle(105, 13)));
    assert.equal(result.member.is_active, true);
    assert.equal(result.member.manually_deactivated, false);
  });
  await check('failed payment rolls back membership and manual reactivation', async () => {
    await addMember(14);
    await asActor(actorA, () => query('select set_member_activation($1,false,0)', [id(14)]));
    const before = await member(14);
    await assert.rejects(asActor(actorA, () => rpc(bundle(106, 14, date, '2026-12-08', { amount: -1 }))), /check constraint/);
    assert.deepEqual(await member(14), before);
    assert.equal((await one('select count(*)::int n from memberships where id=$1', [id(106)])).n, 0);
    assert.equal((await one('select count(*)::int n from payments where id=$1', [id(1106)])).n, 0);
  });
  await check('reconciliation is idempotent and leaves all payment history unchanged', async () => {
    await db.exec('select gym_private.reconcile_membership_lifecycle()');
    const before = (await query('select * from payments order by id')).rows;
    const membersBefore = (await query('select * from members order by id')).rows;
    const historiesBefore = (await query('select * from memberships order by id')).rows;
    const result = (await one('select gym_private.reconcile_membership_lifecycle() result')).result;
    assert.deepEqual(result, { expired_memberships: 0, reconciled_members: 0 });
    assert.deepEqual((await query('select * from members order by id')).rows, membersBefore);
    assert.deepEqual((await query('select * from memberships order by id')).rows, historiesBefore);
    assert.deepEqual((await query('select * from payments order by id')).rows, before);
  });
  await check('soft deletion preserves memberships, payment linkage and member name', async () => {
    await query('update members set deleted_at=now() where id=$1', [id(12)]);
    assert.equal((await member(12)).is_active, false);
    const payment = await one(`select m.full_name,p.amount,p.payment_method from payments p
      join memberships s on s.id=p.membership_id join members m on m.id=s.member_id where m.id=$1`, [id(12)]);
    assert.deepEqual(payment, { full_name: 'Fixture 12', amount: '250', payment_method: 'cash' });
    await assert.rejects(asActor(actorA, () => rpc(bundle(107, 12, '2026-12-09', '2027-01-07'))), /MEMBERSHIP_MEMBER_GYM_MISMATCH/);
  });
  await check('renewal retries after expiration do not duplicate or reactivate', async () => {
    await addMember(15);
    const request = bundle(108, 15, '2026-10-01', '2026-10-30');
    const first = await asActor(actorA, () => rpc(request));
    const again = await asActor(actorA, () => rpc(request));
    assert.equal(first.membership.id, again.membership.id);
    assert.equal(again.membership.status, 'expired');
    assert.equal(again.member.is_active, false);
    assert.equal((await one('select count(*)::int n from payments where membership_id=$1', [id(108)])).n, 1);
  });
  await check('idempotent renewal retry cannot undo a later manual deactivation', async () => {
    await addMember(16);
    const request = bundle(109, 16);
    const created = await asActor(actorA, () => rpc(request));
    await asActor(actorA, () => query('select set_member_activation($1,false,$2)', [id(16), created.member.activation_revision]));
    await db.exec('select gym_private.reconcile_membership_lifecycle()');
    assert.equal((await member(16)).is_active, false);
    const again = await asActor(actorA, () => rpc(request));
    assert.equal(again.member.manually_deactivated, true);
    assert.equal(again.member.is_active, false);
  });
  await check('stale offline deactivation and is_active snapshots cannot undo renewal', async () => {
    await addMember(17);
    await asActor(actorA, () => rpc(bundle(110, 17)));
    await assert.rejects(asActor(actorA, () => query('select set_member_activation($1,false,0)', [id(17)])), /CHANGED_REFRESH/);
    await asActor(actorA, () => query('update members set is_active=false,notes=\'offline edit\' where id=$1', [id(17)]));
    assert.equal((await member(17)).is_active, true);
  });
  await check('cancelled, deleted, unrelated and cross-gym records cannot activate', async () => {
    await addMember(18);
    await addMembership(111, 18, date, '2026-12-08', { status: 'cancelled' });
    await addMembership(112, 18, date, '2026-12-08', { deleted_at: '2026-11-09T00:00:00Z' });
    assert.equal((await member(18)).is_active, false);
    await assert.rejects(addMembership(113, 18, date, '2026-12-08', { gym_id: gymB }), /GYM_MISMATCH/);
  });
  await check('RLS separates both gyms and private processor is not client-executable', async () => {
    await addMember(20, gymB);
    await asActor(actorA, async () => {
      assert.equal((await query('select id from members where gym_id=$1', [gymB])).rows.length, 0);
      await assert.rejects(query('select set_member_activation($1,false,0)', [id(20)]), /NOT_AUTHORIZED/);
      await assert.rejects(db.exec('select gym_private.run_membership_lifecycle()'), /permission denied/);
    });
    await asActor(actorB, async () => {
      assert.equal((await query('select id from members where gym_id=$1', [gymA])).rows.length, 0);
      await assert.rejects(rpc(bundle(114, 20)), /NOT_AUTHORIZED/);
      await assert.rejects(addMembership(115, 17, date, '2026-12-08', { gym_id: gymB }), /GYM_MISMATCH/);
    });
  });
  await check('daily dispatcher runs only once per Cairo day', async () => {
    await db.exec('update gym_private.membership_lifecycle_runs set last_cairo_date=null');
    assert.equal((await one('select gym_private.run_membership_lifecycle() result')).result.skipped, false);
    assert.equal((await one('select gym_private.run_membership_lifecycle() result')).result.skipped, true);
  });
  await check('Cairo calendar boundaries follow winter, summer and DST changes', async () => {
    for (const [instant, expected] of [
      ['2026-01-01T21:59:59Z','2026-01-01'], ['2026-01-01T22:00:00Z','2026-01-02'],
      ['2026-07-01T20:59:59Z','2026-07-01'], ['2026-07-01T21:00:00Z','2026-07-02'],
      ['2026-04-23T21:59:59Z','2026-04-23'], ['2026-04-23T22:00:00Z','2026-04-24'],
      ['2026-10-29T21:59:59Z','2026-10-29'], ['2026-10-29T22:00:00Z','2026-10-30'],
    ]) {
      assert.equal((await one("select (($1::timestamptz at time zone 'Africa/Cairo')::date)::text as cairo_day", [instant])).cairo_day, expected);
    }
  });
  console.log(`All ${passed} database lifecycle checks passed (cron hosting checked separately).`);
} catch (error) {
  console.error(`FAIL after ${passed} checks: ${error.message}`);
  process.exitCode = 1;
} finally {
  await db.close();
}
