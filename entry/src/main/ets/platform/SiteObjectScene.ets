import {
  Camera, CullMode, CustomGeometry, EnvironmentBackgroundType, LightType, MaterialType,
  MetallicRoughnessMaterial, Node, PrimitiveTopology, Quaternion, Scene, SceneResource
} from '@kit.ArkGraphics3D';
import { siteObjectShape } from '../domain/SiteObjectGeometry';

export interface SiteObjectScene {
  scene: Scene;
  object: Node;
  camera: Camera;
  resources: SceneResource[];
}

export function objectRotation(yaw: number, pitch: number): Quaternion {
  const cy = Math.cos(yaw / 2), sy = Math.sin(yaw / 2);
  const cx = Math.cos(pitch / 2), sx = Math.sin(pitch / 2);
  return { x: cy * sx, y: sy * cx, z: -sy * sx, w: cy * cx };
}

// API 26.0.0.105 已核验：Scene.load / factory.create* 都返回 Promise；
// Component3D 接收已创建的 Scene，没有 onSceneReady，也没有独立 ohpm kit 依赖。
// 此函数独占构建中的 Scene，任一步失败即释放；调用者负责成功后的退出释放。
export async function createSiteObjectScene(siteType: string, accentHex: string,
  background: number): Promise<SiteObjectScene> {
  const scene = await Scene.load();
  try {
    const factory = scene.getResourceFactory();
    const resources: SceneResource[] = [];
    const root = scene.root;
    if (!root) throw new Error('OBJECT_SCENE_ROOT_UNAVAILABLE');
    root.visible = true;
    const object = await factory.createNode({ name: 'heritage-form' });
    root.children.append(object);
    object.visible = true;
    object.scale = { x: 1, y: 1, z: 1 };
    object.rotation = objectRotation(0.38, 0.22);
    const camera = await factory.createCamera({ name: 'form-camera' }, { msaa: true });
    root.children.append(camera);
    camera.position = { x: 0, y: 0.12, z: 4.4 };
    camera.fov = 38 * Math.PI / 180;
    camera.nearPlane = 0.1;
    camera.farPlane = 30;
    camera.enabled = true;
    camera.clearColor = { r: ((background >> 16) & 255) / 255,
      g: ((background >> 8) & 255) / 255, b: (background & 255) / 255, a: 1 };
    scene.environment.backgroundType = EnvironmentBackgroundType.BACKGROUND_NONE;
    scene.environment.indirectDiffuseFactor = { x: 0.35, y: 0.32, z: 0.3, w: 1 };
    const key = await factory.createLight({ name: 'form-key' }, LightType.DIRECTIONAL);
    root.children.append(key);
    key.rotation = objectRotation(-0.55, -0.65);
    key.color = { r: 1, g: 0.93, b: 0.85, a: 1 };
    key.intensity = 2.8;
    key.enabled = true;
    key.shadowEnabled = false;
    resources.push(key);
    const fill = await factory.createLight({ name: 'form-fill' }, LightType.DIRECTIONAL);
    root.children.append(fill);
    fill.rotation = objectRotation(2.5, 0.45);
    fill.color = { r: 0.82, g: 0.88, b: 1, a: 1 };
    fill.intensity = 1.3;
    fill.enabled = true;
    fill.shadowEnabled = false;
    resources.push(fill);
    const hex = /^#[0-9a-fA-F]{6}$/.test(accentHex) ? accentHex : '#9B463E';
    const red = parseInt(hex.slice(1, 3), 16) / 255;
    const green = parseInt(hex.slice(3, 5), 16) / 255;
    const blue = parseInt(hex.slice(5, 7), 16) / 255;
    const shape = siteObjectShape(siteType);
    for (const part of shape.meshes) {
      const geometry = new CustomGeometry();
      geometry.topology = PrimitiveTopology.TRIANGLE_LIST;
      geometry.vertices = part.vertices;
      geometry.normals = part.normals;
      geometry.indices = part.indices;
      const resource = await factory.createMesh({ name: `${part.name}-mesh` }, geometry);
      const node = await factory.createGeometry({ name: part.name }, resource);
      object.children.append(node);
      node.visible = true;
      const material = await factory.createMaterial({ name: `${part.name}-clay` },
        MaterialType.METALLIC_ROUGHNESS) as MetallicRoughnessMaterial;
      material.baseColor.factor = { x: Math.min(1, red * part.tone + 0.12),
        y: Math.min(1, green * part.tone + 0.08), z: Math.min(1, blue * part.tone + 0.06), w: 1 };
      // 粗糙陶质避免高反光遮住轮廓。法线由纯几何函数生成，双面同时容纳陶口内侧。
      material.material.factor = { x: 0, y: 0.58, z: 0, w: 1 };
      material.cullMode = CullMode.NONE;
      node.mesh.materialOverride = material;
      resources.push(resource, node, material);
    }
    console.info(`SITE_OBJECT_SCENE:children=${root.children.count()},parts=${object.children.count()},camera=${camera.enabled},position=${JSON.stringify(camera.position)},scale=${JSON.stringify(object.scale)}`);
    return { scene, object, camera, resources };
  } catch (error) {
    scene.destroy();
    throw new Error(`OBJECT_SCENE_CREATE_FAILED:${(error as Error).message}`);
  }
}
