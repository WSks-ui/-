import { randomBytes } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const run = `${Date.now()}_${randomBytes(4).toString('hex')}`;
const fixture = {
  run, username: `demo_${randomBytes(6).toString('hex')}`, password: randomBytes(18).toString('hex'),
  otherUsername: `other_${randomBytes(6).toString('hex')}`, otherPassword: randomBytes(18).toString('hex')
};
// 只生成独立测试账号的随机凭证；资源仅属于 ohosTest 且已被忽略，不写入主包。
// 每次运行换一组账号，旧服务器记录不可能成为本次跨设备回读的前置假数据。
const directory = resolve('entry/src/ohosTest/resources/rawfile');
mkdirSync(directory, { recursive: true });
writeFileSync(resolve(directory, 'account-sync-test.json'), JSON.stringify(fixture));
mkdirSync(resolve('.local/account-sync'), { recursive: true });
writeFileSync(resolve('.local/account-sync/test-run.json'), JSON.stringify(fixture));
process.stdout.write(`已生成独立双端测试凭证，运行编号：${run}\n`);
