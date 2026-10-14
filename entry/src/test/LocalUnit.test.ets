import { describe, it, expect } from '@ohos/hypium';
import { filterSites, emptySnapshot, parseSnapshot, nextTimestamp } from '../main/ets/domain/ArchiveDomain';
import { HERITAGE_SITES } from '../main/ets/data/HeritageCatalog';

export default function localUnitTest() {
  describe('ArchiveDomain', () => {
    it('filters_intersect', 0, () => {
      const sites = filterSites(HERITAGE_SITES, {
        keyword: '都城', city: '洛阳', era: '夏商', type: '都城遗址'
      });
      expect(sites.length).assertEqual(1);
      expect(sites[0].id).assertEqual('ly-erlitou');
    });
    it('snapshot_roundtrip', 0, () => {
      expect(parseSnapshot(JSON.stringify(emptySnapshot('test-device'))).deviceId).assertEqual('test-device');
    });
    it('empty_clock_uses_current_time', 0, () => {
      expect(nextTimestamp([], 100)).assertEqual(100);
    });
  });
}
