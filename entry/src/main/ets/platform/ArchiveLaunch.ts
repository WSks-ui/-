export const DEFAULT_ARCHIVE_STORE: string = 'yunheji_archive_v1';
export const UI_TEST_STORE_PREFIX: string = 'yunheji_test_ui_';

// 设备 UI 回归必须使用独立库。只在 debug 构建接受固定前缀的测试库名，
// 不允许通过外部 Want 任意切换正式库或指定路径；release 始终使用用户档案。
// 此入口只切换存储位置，不注入记录、不模拟保存，也不改变真实页面的操作路径。
export function archiveStoreForLaunch(candidate: Object | undefined, debug: boolean): string {
  if (debug && typeof candidate === 'string' && /^yunheji_test_ui_[a-z0-9_]{1,80}$/.test(candidate)) {
    return candidate;
  }
  return DEFAULT_ARCHIVE_STORE;
}
