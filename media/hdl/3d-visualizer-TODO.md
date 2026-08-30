# Technical Specification Document: Interactive 3D Anatomical & Biomechanical Visualization Engine

**Document Version:** 1.0.0

**Target Audience:** Graphics Engineers (WebGL/WebGPU), Full-Stack Developers, Biomechanical/Medical Data Engineers

**System Designation:** `Project BioKinematics-3D`

---

## 1. Executive Summary & Scope

The objective of this project is to construct a production-ready, client-side 3D web application that renders an anatomically accurate human body model. The system provides two primary functional modes:

1. **Hierarchical Anatomical Inspection Mode:** Real-time mesh picking and raycasting allowing users to select any bodily structure to display synchronized anatomical metadata (Region, Muscle, Bone, Innervation, and Functional Classifications).
2. **Dynamic Kinematics & Positional Terminology Engine:** An interactive manipulation system (Forward/Inverse Kinematics) enabling arbitrary posing of the human rig with a real-time biomechanical analysis engine that computes joint angles, anatomical planes, and generates standardized positional terminology (e.g., *"Right Glenohumeral Joint: 45° Abduction, 20° External Rotation in the Coronal/Scapular Plane"*).

The primary terminology and anatomical ontology will ingest and synchronize with the canonical dataset defined in the project notebook (`e1c43956-61c0-4438-9c63-216c8c92831f`) formatted according to *Terminologia Anatomica* (TA2) standards.

---

## 2. System Architecture

```
                                  +-------------------------------------------------------+
                                  |                     UI / UX Layer                     |
                                  |  (React / Svelte / Web Components + Tailwind CSS)     |
                                  +---------------------------+---------------------------+
                                                              |
                                                              v
+-------------------------------------------------------------------------------------------------------------------------+
|                                                  Application Core State                                                 |
|                                (State Store: Zustand / Redux / Entity Component System)                                 |
+------------------------------------+-----------------------------------------------+------------------------------------+
                                     |                                               |
                                     v                                               v
+------------------------------------+-------------------+   +-----------------------+------------------------------------+
|               3D Graphics & Scene Graph                |   |                Kinematics & Pose Engine                    |
|             (Three.js / WebGPU Renderer)               |   |            (FABRIK / CCD / Two-Bone IK / FK)            |
|                                                        |   |                                                            |
|  - Skeleton Mesh (Individual Bone Geometries)          |   |  - Bone Hierarchy & Joint Axis Transformers                |
|  - Muscular Mesh (Grouped / Layered Geometries)        |   |  - Biomechanical Rotation Constraint Solvers (Euler/Quat)  |
|  - BVH Accelerated Raycaster / GPU ID-Buffer Picking   |   |  - Joint Local Reference Frames (ISB Standard)             |
|  - Shader Materials (Highlight, X-Ray, Ghosting)       |   |  - Real-Time Angle Decomposition & Motion Classifier       |
+------------------------------------+-------------------+   +-----------------------+------------------------------------+
                                     |                                               |
                                     +-----------------------+-----------------------+
                                                             |
                                                             v
                                  +--------------------------+----------------------------+
                                  |       Semantic Anatomical Terminology Engine          |
                                  | (Data Ingestion & Ontology Resolution Layer - TA2/FMA)|
                                  +-------------------------------------------------------+

```

---

## 3. Technology Stack & Dependencies

| Layer | Recommended Technology | Justification |
| --- | --- | --- |
| **Rendering Engine** | Three.js (r160+) / WebGL2 or WebGPU | Universal browser support, mature scene graph, WebAssembly optimizations. |
| **Raycasting Acceleration** | `three-mesh-bvh` | $O(\log N)$ spatial indexing for high-poly anatomical geometries (>1M polygons). |
| **Kinematics Engine** | Custom IK/FK Solver / `three-ik` | Deterministic rotational constraints mapped to physiological joint limits. |
| **Transform Controls** | `TransformControls` (Extended) | Visual 3-axis rotation gizmos per articulation point. |
| **State Management** | Zustand | Zero-overhead, decoupled reactive state outside the 60fps render loop. |
| **Asset Pipeline** | glTF 2.0 / GLB (`KHR_draco_mesh_compression`, `EXT_meshopt_compression`) | Minimized payload size, fast GPU buffer uploads. |
| **Data Normalization** | TypeScript schemas mapped to TA2 / FMA | Strict typing for anatomical relations and ontology hierarchies. |

---

## 4. 3D Model Asset Specifications & Rigging Standards

### 4.1. Mesh Segmentation & Hierarchy

The 3D model must not be a single monolithic mesh. It must be delivered as an indexed glTF/GLB asset separated into anatomical sub-meshes organized into the following strict hierarchy:

```
HumanBody_Root (Skeleton Root / Hips)
├── Skeleton_Group
│   ├── Axial_Skeleton
│   │   ├── Cranium (Frontal, Parietal, Occipital, Sphenoid, etc.)
│   │   ├── Vertebral_Column (C1-C7, T1-T12, L1-L5, Sacrum, Coccyx)
│   │   └── Thoracic_Cage (Sternum, Ribs_1_12)
│   └── Appendicular_Skeleton
│       ├── Pectoral_Girdle_L / _R (Clavicle, Scapula)
│       ├── Upper_Limbs_L / _R (Humerus, Radius, Ulna, Carpals, Metacarpals, Phalanges)
│       ├── Pelvic_Girdle (Ilium, Ischium, Pubis)
│       └── Lower_Limbs_L / _R (Femur, Patella, Tibia, Fibula, Tarsals, Metatarsals, Phalanges)
├── Muscular_Group
│   ├── Head_Neck (Sternocleidomastoid, Masseter, Trapezius_Superior, etc.)
│   ├── Torso_Anterior (Pectoralis_Major, Rectus_Abdominis, Obliques, etc.)
│   ├── Torso_Posterior (Latissimus_Dorsi, Rhomboids, Trapezius, Erector_Spinae)
│   ├── Upper_Extremity_L / _R (Deltoid, Biceps_Brachii, Triceps_Brachii, Forearm_Flexors)
│   └── Lower_Extremity_L / _R (Gluteus_Maximus, Quadriceps, Hamstrings, Gastrocnemius, etc.)
└── Integumentary_Group (Surface skin with alpha-blend/ghosting capability)

```

### 4.2. Rigging and Joint Conventions (ISB Standard)

To ensure dynamic angle extraction conforms to physiological science, joints must follow the **International Society of Biomechanics (ISB)** reference frames:

* **Default Position (Identity $q_0$):** Standard Anatomical Position (standing erect, arms at sides, palms facing anteriorly, feet forward).
* **Coordinate Axes per Joint:**
* **$X$-Axis (Red):** Mediolateral axis (Transverse axis $\rightarrow$ Sagittal plane motion: **Flexion / Extension**).
* **$Y$-Axis (Green):** Longitudinal/Inferior-Superior axis (Vertical axis $\rightarrow$ Transverse plane motion: **Internal / External Rotation**; **Pronation / Supination** for forearm).
* **$Z$-Axis (Blue):** Anteroposterior axis (Sagittal axis $\rightarrow$ Coronal/Frontal plane motion: **Abduction / Adduction**; **Lateral Flexion**).



---

## 5. Data Schemas & Integration

### 5.1. Anatomical Data Schema (TypeScript Definition)

```typescript
export interface AnatomicalEntity {
  id: string;                      // Matches Mesh Node Name in GLTF (e.g., "BICEPS_BRACHII_L")
  canonicalName: string;           // "Biceps Brachii"
  latinName: string;               // "Musculus biceps brachii"
  system: 'skeletal' | 'muscular' | 'integumentary' | 'nervous' | 'vascular';
  region: AnatomicalRegion;        // Hierarchical region
  details: {
    origin?: string[];             // For muscles: Bone landmark origins
    insertion?: string[];          // For muscles: Bone landmark insertions
    action?: string[];             // Primary anatomical actions
    innervation?: string;          // Nerve supply
    bloodSupply?: string;          // Arterial supply
    articulation?: string[];       // For bones: adjacent joint articulations
    boneMarkings?: string[];       // Specific bony landmarks (e.g., "Greater Tubercle")
  };
  metadata: {
    ta2_code: string;              // Terminologia Anatomica 2 unique identifier
    fma_id: number;                // Foundational Model of Anatomy identifier
  };
}

export interface AnatomicalRegion {
  primary: 'Head' | 'Neck' | 'Thorax' | 'Abdomen' | 'Pelvis' | 'Upper Limb' | 'Lower Limb';
  secondary: string;               // e.g., "Brachium (Arm)", "Antebrachium (Forearm)"
  tertiary?: string;               // e.g., "Anterior Compartment"
}

```

### 5.2. Biomechanical Joint & Kinematics Schema

```typescript
export interface JointKinematicState {
  jointId: string;                 // e.g., "GLENOHUMERAL_R", "KNEE_L", "C1_C2_ATLANTOAXIAL"
  jointName: string;               // "Right Shoulder (Glenohumeral) Joint"
  degreesOfFreedom: number;        // 1, 2, or 3 DOF
  currentEulerAngles: {
    sagittal: number;              // Degrees (Flexion [+] / Extension [-])
    coronal: number;               // Degrees (Abduction [+] / Adduction [-])
    transverse: number;            // Degrees (Internal Rot [+] / External Rot [-])
  };
  limits: {
    sagittalMinMax: [number, number];   // e.g., [-60, 180]
    coronalMinMax: [number, number];    // e.g., [0, 180]
    transverseMinMax: [number, number]; // e.g., [-90, 90]
  };
  generatedTerminology: string[];       // e.g., ["Flexion (45°)", "External Rotation (15°)"]
}

```

---

## 6. Core Functional Modules & Implementation

### 6.1. Module A: 3D Raycasting & Hierarchical Picking Engine

To achieve sub-millisecond picking on detailed anatomical models:

1. **GPU Bounding Volume Hierarchy (BVH):** Compute BVH for all skeletal and muscular geometries upon model load using `three-mesh-bvh`.
2. **Selection Flow:**
* Execute pointer raycast against BVH-accelerated meshes.
* Extract intersection object node name (`intersect.object.name`).
* Query the unified anatomical data map (O(1) lookup).
* Apply visual highlight shader (Emission rim-light + unselected group ghosting).



```typescript
import { Raycaster, Vector2, Camera, Scene, MeshStandardMaterial, Color } from 'three';
import { computeBoundsTree, disposeBoundsTree, acceleratedRaycast } from 'three-mesh-bvh';

// Inject BVH acceleration into Three.js primitives
BufferGeometry.prototype.computeBoundsTree = computeBoundsTree;
BufferGeometry.prototype.disposeBoundsTree = disposeBoundsTree;
Mesh.prototype.raycast = acceleratedRaycast;

export class AnatomicalPicker {
  private raycaster: Raycaster;
  private pointer: Vector2;
  private highlightedMesh: Mesh | null = null;
  private defaultMaterialCache: Map<string, Material> = new Map();

  constructor() {
    this.raycaster = new Raycaster();
    this.raycaster.firstHitOnly = true; // Optimization: bail on first hit
    this.pointer = new Vector2();
  }

  public pick(
    event: MouseEvent | TouchEvent,
    camera: Camera,
    targetGroup: Object3D,
    dataRegistry: Map<string, AnatomicalEntity>
  ): AnatomicalEntity | null {
    const rect = canvas.getBoundingClientRect();
    const clientX = 'touches' in event ? event.touches[0].clientX : event.clientX;
    const clientY = 'touches' in event ? event.touches[0].clientY : event.clientY;

    this.pointer.x = ((clientX - rect.left) / rect.width) * 2 - 1;
    this.pointer.y = -((clientY - rect.top) / rect.height) * 2 + 1;

    this.raycaster.setFromCamera(this.pointer, camera);
    const intersects = this.raycaster.intersectObjects(targetGroup.children, true);

    if (intersects.length > 0) {
      const hitMesh = intersects[0].object as Mesh;
      const entityData = dataRegistry.get(hitMesh.name);

      if (entityData) {
        this.highlightEntity(hitMesh);
        return entityData;
      }
    }
    this.clearHighlight();
    return null;
  }

  private highlightEntity(mesh: Mesh) {
    this.clearHighlight();
    this.highlightedMesh = mesh;
    this.defaultMaterialCache.set(mesh.uuid, mesh.material as Material);
    
    // Apply Highlight Material with Edge Glow
    mesh.material = new MeshStandardMaterial({
      color: new Color(0x00aaff),
      emissive: new Color(0x004488),
      roughness: 0.3,
      metalness: 0.1,
    });
  }

  public clearHighlight() {
    if (this.highlightedMesh) {
      const origMat = this.defaultMaterialCache.get(this.highlightedMesh.uuid);
      if (origMat) this.highlightedMesh.material = origMat;
      this.highlightedMesh = null;
    }
  }
}

```

---

### 6.2. Module B: Positional Kinematics & Dynamic Posing Engine

#### Dynamic Joint Angle Decomposition Algorithm

To calculate anatomical movement without Gimbal lock, rotation is maintained as Quaternions and decomposed into the joint's intrinsic coordinate basis:

$$\mathbf{q}_{\text{relative}} = \mathbf{q}_{\text{parent}}^{-1} \cdot \mathbf{q}_{\text{joint}}$$

Let $\mathbf{q}_{\text{relative}} = (w, x, y, z)$. We project the relative rotation into Tait-Bryan angles with rotation sequence tailored to the joint's primary axis (e.g., $Z\text{-}X\text{-}Y$ or $X\text{-}Y\text{-}Z$ depending on the anatomical joint).

```typescript
import { Bone, Euler, Quaternion, Vector3, MathUtils } from 'three';

export class BiomechanicalPoseEvaluator {
  private static readonly EPSILON = 2.0; // Degrees threshold to eliminate noise

  /**
   * Decomposes local joint transform into standardized anatomical terminology
   */
  public static evaluateJointKinematics(
    jointBone: Bone,
    jointConfig: JointKinematicConfig
  ): JointKinematicState {
    const euler = new Euler();
    
    // Decompose using the defined anatomical gimbal-safe sequence for this joint
    euler.setFromQuaternion(jointBone.quaternion, jointConfig.eulerOrder);

    const degX = MathUtils.radToDeg(euler.x); // Sagittal Plane
    const degY = MathUtils.radToDeg(euler.y); // Transverse Plane
    const degZ = MathUtils.radToDeg(euler.z); // Coronal Plane

    const descriptiveTerms: string[] = [];

    // 1. Sagittal Analysis (Flexion / Extension)
    if (Math.abs(degX) > this.EPSILON) {
      if (degX > 0) {
        descriptiveTerms.push(`${jointConfig.sagittalPositiveTerm} (${degX.toFixed(1)}°)`);
      } else {
        descriptiveTerms.push(`${jointConfig.sagittalNegativeTerm} (${Math.abs(degX).toFixed(1)}°)`);
      }
    }

    // 2. Coronal Analysis (Abduction / Adduction / Lateral Flexion)
    if (Math.abs(degZ) > this.EPSILON) {
      if (degZ > 0) {
        descriptiveTerms.push(`${jointConfig.coronalPositiveTerm} (${degZ.toFixed(1)}°)`);
      } else {
        descriptiveTerms.push(`${jointConfig.coronalNegativeTerm} (${Math.abs(degZ).toFixed(1)}°)`);
      }
    }

    // 3. Transverse Analysis (Internal / External Rotation; Supination / Pronation)
    if (Math.abs(degY) > this.EPSILON) {
      if (degY > 0) {
        descriptiveTerms.push(`${jointConfig.transversePositiveTerm} (${degY.toFixed(1)}°)`);
      } else {
        descriptiveTerms.push(`${jointConfig.transverseNegativeTerm} (${Math.abs(degY).toFixed(1)}°)`);
      }
    }

    if (descriptiveTerms.length === 0) {
      descriptiveTerms.push('Neutral Anatomical Position (0.0°)');
    }

    return {
      jointId: jointBone.name,
      jointName: jointConfig.friendlyName,
      degreesOfFreedom: jointConfig.dof,
      currentEulerAngles: {
        sagittal: degX,
        coronal: degZ,
        transverse: degY
      },
      limits: jointConfig.limits,
      generatedTerminology: descriptiveTerms
    };
  }
}

```

---

## 7. Joint Movement Terminology Mapping Matrix

The engine maps angular displacement to physiological terminology using the following dictionary matrix:

| Joint Name | Axis / Plane | Positive Displacement (+) | Negative Displacement (-) | Normal ROM (Range of Motion) |
| --- | --- | --- | --- | --- |
| **Glenohumeral (Shoulder)** | $X$ (Sagittal)<br>

<br>$Z$ (Coronal)<br>

<br>$Y$ (Transverse) | **Flexion** (Anterior)<br>

<br>**Abduction** (Lateral)<br>

<br>**Internal (Medial) Rotation** | **Extension** (Posterior)<br>

<br>**Adduction** (Medial)<br>

<br>**External (Lateral) Rotation** | Flex: 0–180°, Ext: 0–60°<br>

<br>Abd: 0–180°, Add: 0–50°<br>

<br>Int: 0–90°, Ext: 0–90° |
| **Humeroulnar (Elbow)** | $X$ (Sagittal) | **Flexion** | **Extension** | Flex: 0–150°, Ext: 0° |
| **Radioulnar (Forearm)** | $Y$ (Transverse) | **Pronation** | **Supination** | Pro: 0–80°, Sup: 0–80° |
| **Radiocarpal (Wrist)** | $X$ (Sagittal)<br>

<br>$Z$ (Coronal) | **Flexion** (Palmar)<br>

<br>**Radial Deviation** (Abduction) | **Extension** (Dorsiflexion)<br>

<br>**Ulnar Deviation** (Adduction) | Flex: 0–80°, Ext: 0–70°<br>

<br>Rad: 0–20°, Uln: 0–30° |
| **Acetabulofemoral (Hip)** | $X$ (Sagittal)<br>

<br>$Z$ (Coronal)<br>

<br>$Y$ (Transverse) | **Flexion**<br>

<br>**Abduction**<br>

<br>**Internal Rotation** | **Extension**<br>

<br>**Adduction**<br>

<br>**External Rotation** | Flex: 0–120°, Ext: 0–30°<br>

<br>Abd: 0–45°, Add: 0–30°<br>

<br>Int: 0–45°, Ext: 0–45° |
| **Tibiofemoral (Knee)** | $X$ (Sagittal) | **Flexion** | **Extension** | Flex: 0–140°, Ext: 0° |
| **Talocrural (Ankle)** | $X$ (Sagittal)<br>

<br>$Z$ (Coronal) | **Dorsiflexion**<br>

<br>**Inversion** (Subtalar) | **Plantarflexion**<br>

<br>**Eversion** (Subtalar) | Dorsi: 0–20°, Plantar: 0–50°<br>

<br>Inv: 0–35°, Ever: 0–15° |
| **Cervical / Lumbar Spine** | $X$ (Sagittal)<br>

<br>$Z$ (Coronal)<br>

<br>$Y$ (Transverse) | **Forward Flexion**<br>

<br>**Lateral Flexion (Left)**<br>

<br>**Rotation (Left)** | **Extension**<br>

<br>**Lateral Flexion (Right)**<br>

<br>**Rotation (Right)** | Cervical Flex: 0–45°, Ext: 0–45°<br>

<br>Lat: 0–45°, Rot: 0–60° |

---

## 8. Data Ingestion Pipeline for Project Notebook

To ingest and sync data from the reference notebook (`e1c43956-61c0-4438-9c63-216c8c92831f`), the pipeline implements an extraction and validation workflow:

```
[Notebook Source (HTML/JSON/Markdown Data)]
                     │
                     ▼
       [ETL Parser: node-ingest.ts]
  ├── Regex & Structured AST Table Parsing
  ├── Schema Validation (Zod Validation Engine)
  └── Foreign Key Linking (Bone ID <-> Muscle Origins)
                     │
                     ▼
[Build-Time Artifact: anatomical_registry.min.json]
                     │
                     ▼
  [Client-Side Binary Map Load (IndexedDB)]

```

### 8.1. Zod Validation Engine for Ingestion Integrity

```typescript
import { z } from 'zod';

export const AnatomicalEntitySchema = z.object({
  id: z.string().min(1),
  canonicalName: z.string().min(1),
  latinName: z.string(),
  system: z.enum(['skeletal', 'muscular', 'integumentary', 'nervous', 'vascular']),
  region: z.object({
    primary: z.enum(['Head', 'Neck', 'Thorax', 'Abdomen', 'Pelvis', 'Upper Limb', 'Lower Limb']),
    secondary: z.string(),
    tertiary: z.string().optional()
  }),
  details: z.object({
    origin: z.array(z.string()).optional(),
    insertion: z.array(z.string()).optional(),
    action: z.array(z.string()).optional(),
    innervation: z.string().optional(),
    bloodSupply: z.string().optional(),
    articulation: z.array(z.string()).optional(),
    boneMarkings: z.array(z.string()).optional()
  }),
  metadata: z.object({
    ta2_code: z.string().regex(/^[A-Z0-9\.]+$/),
    fma_id: z.number().int().positive()
  })
});

export type ValidatedAnatomicalEntity = z.infer<typeof AnatomicalEntitySchema>;

```

---

## 9. Performance & Rendering Constraints

| Parameter | Target Metric | Engineering Strategy |
| --- | --- | --- |
| **Frame Rate** | Sustained 60 FPS | Delta-time decoupled updates; dynamic resolution scaling during camera orbit. |
| **VRAM Consumption** | $\le 150 \text{ MB}$ | Shared standard materials with vertex attribute buffers; KTX2/Basis texture compression. |
| **Initial Asset Bundle** | $\le 12 \text{ MB}$ (Gzipped) | Draco mesh compression (level 7); aggressive LOD (Level of Detail) 0/1/2 switching. |
| **Raycasting Latency** | $< 2 \text{ ms}$ | `three-mesh-bvh` BVH caching; spatial bounding hierarchy tree. |
| **Inverse Kinematics Tick** | $< 4 \text{ ms}$ per pose solve | Solvers executed inside Web Worker threads (OffscreenCanvas optional for UI decoupling). |

---

## 10. Engineering Milestones & Sprint Schedule

```
Sprint 1: Pipeline & Architecture Setup
  ├── Setup Three.js/WebGPU baseline scene, camera controls, lighting.
  ├── Model normalization: Split glTF sub-meshes, apply ISB joint axes, verify UVs/normals.
  └── Build ingestion script for dataset notebook parsing into validated JSON registry.

Sprint 2: Anatomical Inspection & Raycasting Engine
  ├── Integrate `three-mesh-bvh` for all sub-meshes.
  ├── Implement pointer hover/click raycasting and ID resolver.
  ├── Create highlight and isolation (X-Ray/Ghosting) visual shaders.
  └── Build overlay UI panel for anatomical terminology display.

Sprint 3: Kinematic Rigging & Joint Controls
  ├── Implement skeletal bone hierarchy with Forward Kinematics (FK) rotational gizmos.
  ├── Define joint rotation constraints (Euler/Quaternion clamps matching anatomical ROM).
  └── Implement Inverse Kinematics (IK) solvers for extremities (Feet, Hands, Head).

Sprint 4: Real-Time Biomechanical Terminology Engine
  ├── Implement quaternion decomposition algorithm across all anatomical planes.
  ├── Implement movement classifier string generator (Flexion, Abduction, etc.).
  ├── Real-time UI HUD for whole-body posture descriptor readouts.

Sprint 5: Performance Optimization, QA & Acceptance Testing
  ├── Draco & KTX2 compression pipeline pass.
  ├── Cross-browser WebGL/WebGPU and touch-device testing.
  └── Medical validation review against Terminologia Anatomica dataset.

```

---

## 11. Acceptance Criteria & Definition of Done (DoD)

1. **Precision Selection:** Clicking any muscle or bone must populate accurate region, Latin nomenclature, origins, insertions, and innervations within $\le 50\text{ms}$.
2. **Kinematic Reliability:** Posing the limb (e.g., pulling the hand upward) must accurately compute joint angles and continuously update the UI (e.g., displaying *"Glenohumeral Joint: 90° Abduction, 30° Horizontal Adduction"*).
3. **Collision & Constraint Handling:** Limbs must not violate natural anatomical range-of-motion limits (e.g., the elbow cannot hyperextend beyond 0° to negative angles).
4. **Data Fidelity:** 100% of the anatomical entities defined in the project notebook must map to corresponding node identifiers in the 3D model scene graph.
