import archiveDeviceTest from './Archive.test';
import archiveUiTest from './ArchiveUi.test';
import archiveRestartTest from './ArchiveRestart.test';
import archiveAppearanceTest from './ArchiveAppearance.test';
import archiveImmersiveTest from './ArchiveImmersive.test';
import cultureAtlasTest from './CultureAtlas.test';
import accountSyncTest from './AccountSync.test';
import profileLoginTest from './ProfileLogin.test';
import catalogGraphTest from './CatalogGraph.test';
import spatialExperienceTest from './SpatialExperience.test';
import engineExperienceTest from './EngineExperience.test';

export default function testsuite() {
  archiveDeviceTest();
  archiveUiTest();
  archiveRestartTest();
  archiveAppearanceTest();
  archiveImmersiveTest();
  cultureAtlasTest();
  accountSyncTest();
  profileLoginTest();
  catalogGraphTest();
  spatialExperienceTest();
  engineExperienceTest();
}
