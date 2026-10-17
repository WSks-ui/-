import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';

const moduleUrls = new Map();

// ArkTS 领域源码保留无扩展名导入；本地测试只改装载地址，不复制实现逻辑。
// 先剥离 type 导入，使配置与接口的双向引用不会产生运行期循环。
export function domainModuleUrl(name) {
  if (moduleUrls.has(name)) return moduleUrls.get(name);
  const sourceUrl = new URL(`../entry/src/main/ets/domain/${name}.ts`, import.meta.url);
  const source = stripTypeScriptTypes(readFileSync(sourceUrl, 'utf8'))
    .replace(/from\s+(['"])\.\/([A-Za-z0-9_]+)\1/g,
      (_match, _quote, dependency) => `from '${domainModuleUrl(dependency)}'`);
  // base64 避免源码中的单引号留在嵌套 import 地址里；encodeURIComponent 不会转义单引号。
  const url = `data:text/javascript;base64,${Buffer.from(source, 'utf8').toString('base64')}`;
  moduleUrls.set(name, url);
  return url;
}
