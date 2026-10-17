import { readFileSync, writeFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { createHash } from 'node:crypto';

// 数学规则只维护 TypeScript 源，离线 Web 使用擦除类型后的相同实现。
// 修改规则后运行本脚本；测试会拒绝来源哈希与源文件不一致的产物。
for (const [sourceName, outputName, className] of [
  ['CultureGraphLayout', 'graph-layout', 'GraphLayout'], ['CultureGraphSpace', 'graph-space', 'GraphSpace']
]) {
  const sourceUrl = new URL(`../src/main/ets/domain/${sourceName}.ts`, import.meta.url);
  const source = readFileSync(sourceUrl, 'utf8').replace(/\r\n/g, '\n');
  const hash = createHash('sha256').update(source).digest('hex');
  const code = stripTypeScriptTypes(source.replace(/^import type .*;\r?\n/gm, '').replace(/^export /gm, ''));
  writeFileSync(new URL(`../src/main/resources/rawfile/${outputName}.js`, import.meta.url),
    `/* Generated from ${sourceName}.ts; source-sha256: ${hash} */\n(function(root) {\n'use strict';\n${code}\nroot.Yunheji${className} = ${className};\n})(globalThis);\n`);
}
