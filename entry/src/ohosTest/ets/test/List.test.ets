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
import memoryJourneyTest from './MemoryJourney.test';
import coreContentTest from './CoreContent.test';
import observationMemoryTest from './ObservationMemory.test';
import expandedObservationTest from './ExpandedObservation.test';
import homeExperienceTest from './HomeExperience.test';
import materialComparisonTest from './MaterialComparison.test';
import memorySyncTest from './MemorySync.test';
import demoRehearsalTest from './DemoRehearsal.test';
import pageHierarchyTest from './PageHierarchy.test';
import waterSituationTest from './WaterSituation.test';
import stageFoundationTest from './StageFoundation.test';
import contentMemoryTest from './ContentMemory.test';
import aiMemorySyncTest from './AiMemorySync.test';
import journeyScrollTest from './JourneyScroll.test';
import roamingTest from './Roaming.test';
import roamingSyncTest from './RoamingSync.test';
import roamingTabletTest from './RoamingTablet.test';
import roamingLoginTest from './RoamingLogin.test';
import paperJourneyTest from './PaperJourney.test';
import paperJourneySyncTest from './PaperJourneySync.test';
import paperSystemTest from './PaperSystem.test';
import paperExcerptTest from './PaperExcerpt.test';
import paperLightTest from './PaperLight.test';
import riverPaperPerfTest from './RiverPaperPerf.test';
import riverMarketTest from './RiverMarket.test';
import marketNightsTest from './MarketNights.test';
import marketNightsCultureTest from './MarketNightsCulture.test';
import marketNightsSyncTest from './MarketNightsSync.test';

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
  memoryJourneyTest();
  coreContentTest();
  observationMemoryTest();
  expandedObservationTest();
  homeExperienceTest();
  materialComparisonTest();
  memorySyncTest();
  demoRehearsalTest();
  pageHierarchyTest();
  waterSituationTest();
  stageFoundationTest();
  contentMemoryTest();
  aiMemorySyncTest();
  journeyScrollTest();
  // 漫游定向套件在入口内核对显式 class=RoamingTest，不加入未指定类的历史回归。
  roamingTest();
  roamingSyncTest();
  roamingTabletTest();
  roamingLoginTest();
  // 新纸景只在显式class=PaperJourneyTest时注册，不改变旧登录与漫游专项的入口约定。
  paperJourneyTest();
  // 三阶段双端专项必须显式指定class，不混入单端或历史回归。
  paperJourneySyncTest();
  // 分享取消与普通桌面卡片仅在显式class=PaperSystemTest时注册。
  paperSystemTest();
  // 真平板跨Text选摘、UDMF拖卡与确认保存仅在显式class=PaperExcerptTest时注册。
  paperExcerptTest();
  // 移动光源的真实剪口/PNG像素专项仅在显式 class=PaperLightTest 时注册。
  paperLightTest();
  // 连续笔迹与移光采样走真实手势，仅显式RiverPaperPerfTest注册。
  riverPaperPerfTest();
  // 汴京开市真实经营、回放连点与普通记忆保留仅在显式 class=RiverMarketTest 时注册。
  riverMarketTest();
  // 三夜逐批经营使用显式阶段与独立库，不写入正式档案或混入旧回归。
  marketNightsTest();
  marketNightsCultureTest();
  marketNightsSyncTest();
}
