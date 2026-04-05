# Counting Common Nets of the Dodecahedron and the Great Dodecahedron

## Problem Statement

A **net** of a polyhedron is a planar arrangement of its faces obtained by cutting along edges and unfolding to a flat shape. For a dodecahedron (12 pentagonal faces, 30 edges, 20 vertices), every net corresponds to a **spanning tree** of the dual graph of edges-between-faces (the face-adjacency graph). A spanning tree selects 11 of the 30 edges as "fold edges" (hinges); the remaining 19 edges are cut.

The regular dodecahedron {5, 3} and the great dodecahedron {5, 5/2} share the same face shape (regular pentagons) and the same number of faces (12). They differ in how faces are arranged: the dihedral angle of the great dodecahedron causes faces to interpenetrate.

### The question

Given a net (spanning tree) of the dodecahedron, we can fold it in two ways:

1. **Fold to dodecahedron**: use the dodecahedral dihedral angle (~116.57°). Every spanning tree folds back into the dodecahedron — by construction.
2. **Fold to great dodecahedron**: instead of the dodecahedral dihedral angle, use the great dodecahedral dihedral angle at each hinge. This causes faces to intersect. Sometimes all 12 distinct face positions of the great dodecahedron are covered; sometimes faces collide (two or more faces land on the same position), leaving fewer than 12 distinct positions covered.

A net is a **"good net"** (common net) if the second folding covers all 12 faces of the great dodecahedron. Such a net is a **common net** of both the dodecahedron and the great dodecahedron.

### Why the same spanning trees apply to both polyhedra

The face-adjacency graph of a polyhedron is determined by its dual's 1-skeleton. The key observation is:

- Dual of dodecahedron {5, 3} = icosahedron {3, 5} → 12 vertices, 30 edges
- Dual of great dodecahedron {5, 5/2} = small stellated dodecahedron {5/2, 5} → 12 vertices, 30 edges

The icosahedron and small stellated dodecahedron share the same 12 vertices and 30 edges (the same 1-skeleton). They are both 5-regular graphs on 12 vertices, isomorphic as abstract graphs, and have the same Laplacian spectrum: {5+√5 (×3), 6 (×5), 5−√5 (×3), 0 (×1)}.

Applying Kirchhoff's matrix tree theorem to both:

$$\text{# spanning trees} = \frac{1}{12} (5+\sqrt{5})^3 \cdot 6^5 \cdot (5-\sqrt{5})^3 = \frac{1}{12} \cdot 20^3 \cdot 7776 = 5{,}184{,}000$$

This was verified computationally by constructing both dual graphs explicitly and computing the determinant of the reduced Laplacian.

Since the two dual graphs share the same 1-skeleton, the face-adjacency pairs are identical: two faces share a dodecahedral edge if and only if they share a great-dodecahedral edge (though the geometric edges themselves differ — the dodecahedron has 20 vertices while the great dodecahedron has 12). This is why a single spanning tree can serve as a net for both polyhedra, differing only in the dihedral angle used at each hinge.

## Algorithm in `count_dodecahedron_nets.wls`

### Step 1: Generate the dodecahedron faces

`generateFaces[5, 3]` builds the 12 faces of a regular dodecahedron {5, 3} via Wythoff construction (reflections through mirror planes). Each face is a list of 5 vertices in 3D.

### Step 2: Build the face-adjacency graph

An adjacency matrix `adjMatrix` is computed: face i is adjacent to face j iff they share exactly 2 vertices (i.e., a common edge). This gives a graph with 12 vertices and 30 edges — the 1-skeleton of the icosahedron (the dual of the dodecahedron).

### Step 3: Enumerate spanning trees

The script enumerates all spanning trees of this 12-vertex, 30-edge graph. Kirchhoff's matrix tree theorem tells us the count is **5,184,000**. The enumeration is done by:

- Selecting the first 5 edges and iterating over all 2^5 = 32 subsets of those edges.
- For each subset, combining with subsets of the remaining 25 edges chosen to bring the total to 11 edges (a spanning tree has V−1 = 11 edges).
- Filtering to keep only connected acyclic subgraphs (spanning trees).

This partition into "first edges" and "other edges" is a performance optimization to reduce memory usage, since C(30,11) ≈ 54.6 million edge subsets would be too large to hold in memory at once.

### Step 4: For each spanning tree, fold into the great dodecahedron

Each spanning tree defines a rooted tree (rooted at some face). The function `buildSchedule` constructs a sequence of fold operations from root to leaves. The function `foldFaces` applies rotations at each hinge edge:

- **`angleToStellate`**: the rotation angle that transforms the dodecahedral dihedral angle to the great dodecahedral dihedral angle. Computed as `−2 × (original dihedral) + π`.
- Folds are applied hierarchically: when rotating a face, all its descendant faces in the tree are rotated together.

### Step 5: Check if the folded configuration covers all 12 faces

After folding, `exportFrame` computes the centers of all 12 rotated faces and tallies them using approximate equality. If there are **12 distinct face centers**, the net is "good" — it covers all 12 faces of the great dodecahedron.

### Key functions

| Function | Role |
|---|---|
| `generateFaces[p, q]` | Wythoff construction of the faces of {p, q} |
| `adjacentFaces[f1, f2]` | Tests if two faces share an edge (2 common vertices) |
| `buildSchedule[tree, ...]` | Converts a spanning tree into a fold schedule |
| `foldFaces[faces, schedule, percents]` | Applies rotations at each hinge to fold the net |
| `exportFrame[...]` | Folds and checks whether all 12 face positions are covered |

## Results (from labeled enumeration)

| Quantity | Value |
|---|---|
| Number of faces | 12 |
| Number of edges (adjacency graph) | 30 |
| Number of spanning trees (labeled) | 5,184,000 |
| Number of good nets (labeled) | 7,320 |
| Ratio (trees per good net) | ≈ 708.2 |
| Number of "worst" nets (only 6 unique faces) | 188,880 |

Good nets are quite rare: roughly 1 in 708 spanning trees folds into a valid great dodecahedron.

---

## Spanning Trees vs. Distinct Nets

### The problem of labeling

The 5,184,000 count enumerates **labeled** spanning trees: each tree is a specific subset of 11 edges of the face-adjacency graph with faces labeled 1–12. Two different labeled trees that are related by a symmetry of the dodecahedron produce the **same geometric net** (same 2D planar shape, up to rigid motion).

The well-known count of **43,380 distinct nets** for the regular dodecahedron is obtained by quotienting out the symmetry group. Since the face-adjacency graph is identical for both polyhedra (see above), the great dodecahedron also has exactly **43,380 distinct nets**.

### Symmetry group

The **full icosahedral symmetry group** Ih has order 120 and consists of:
- 60 rotations (the rotation group I ≅ A₅)
- 60 improper rotations (rotations composed with inversion/reflection)

Each symmetry acts on the 12 faces as a permutation π ∈ S₁₂. Two labeled spanning trees T₁ and T₂ represent the **same distinct net** if there exists a symmetry π such that π(T₁) = T₂, where π acts on a tree's edge set by permuting face labels.

### Why simple division doesn't give 43,380

By Burnside's lemma (a.k.a. the Cauchy–Frobenius lemma):

$$\text{# distinct nets} = \frac{1}{|G|} \sum_{g \in G} |\text{Fix}(g)|$$

where Fix(g) is the number of spanning trees invariant under symmetry g.

- Simple division: 5,184,000 / 120 = 43,200
- Burnside gives: **43,380**
- The difference of 180 comes from spanning trees that are invariant under some non-identity symmetry. These trees have orbits of size < 120, so they contribute "extra" to the orbit count.
- Equivalently: Σ_{g≠e} |Fix(g)| = 43,380 × 120 − 5,184,000 = **21,600** total extra fixed points from non-trivial symmetries.

### Orbit structure of all 43,380 dodecahedron nets

The possible orbit sizes for spanning trees are constrained by the structure of Ih and the fact that a spanning tree has 11 edges. The only possible orbit sizes are **60** and **120** — no others. This is proved by ruling out all stabilizer subgroups of order ≥ 3:

**No element of order 3 or 5 can fix a spanning tree.** A C₃ rotation permutes 12 faces in four 3-cycles (no fixed points), so all edge orbits under C₃ have size 3. Since 11 is not divisible by 3, no invariant spanning tree exists. The same argument applies to C₅: edge orbits have size 5, and 11 is not divisible by 5.

**No element whose group contains the inversion can fix a spanning tree.** The inversion permutes all 12 faces in 6 transpositions, with no adjacent pair forming a transposition (opposite faces are at distance 3 in the icosahedron graph). So all edge orbits have size 2, but 11 is odd. This rules out the inversion directly, and also rules out S₆ (whose cube is the inversion) and S₁₀ (whose fifth power is the inversion).

**No Klein four-group V₄ can fix a spanning tree.** There are 35 Klein four-groups in Ih. For V₄ subgroups consisting of 3 C₂ rotations: no edge can be simultaneously fixed by all three (if two C₂ rotations both swap the endpoints of an edge, their product fixes a vertex, contradicting C₂ rotations having no fixed vertices). All edge orbits therefore have size 2 or 4 (even), and 11 is odd. For V₄ subgroups containing reflections: size-1 edge orbits do exist (a reflection can fix an edge whose endpoints are both on the mirror plane), but a connectivity analysis of the quotient graph shows the vertex orbits (1 of size 4, 4 of size 2 = 5 groups) cannot be spanned — the mandatory self-loop orbits consume edge-orbit slots, leaving too few inter-group bridges. This was verified by exhaustive computation over all 35 V₄ subgroups.

**Therefore, stabilizers have order at most 2**, and the only possible orbit sizes are 60 (stabilizer = one involution) and 120 (trivial stabilizer). Solving:

| Orbit size | Stabilizer | Count | Labeled trees |
|---|---|---|---|
| 120 | trivial | 43,020 | 5,162,400 |
| 60 | order 2 | 360 | 21,600 |
| **Total** | | **43,380** | **5,184,000** |

Only 360 out of 43,380 nets (0.83%) have any non-trivial symmetry.

### Distinct good nets (common nets)

For good nets:
- Labeled count: **7,320**
- 7,320 / 120 = 61 exactly — but this does **not** imply all orbits have size 120.
- Computation (see `classify_good_nets.wls`) reveals **74 distinct good nets**, with two types:

| Orbit size | Count | Stabilizer order | Labeled trees |
|---|---|---|---|
| 120 | 48 | 1 (trivial) | 48 × 120 = 5,760 |
| 60 | 26 | 2 | 26 × 60 = 1,560 |
| **Total** | **74** | | **7,320** |

The earlier prediction of 61 was wrong because exact divisibility of the labeled count by the group order is a necessary but not sufficient condition for all orbits to have full size. The coincidence masked 26 smaller orbits.

### Why common nets are enriched for symmetry

The common-net property selects for 2-fold symmetry at a dramatic rate:

| | Orbit-60 | Orbit-120 |
|---|---|---|
| All dodecahedron nets | 360 (0.83%) | 43,020 (99.17%) |
| Common nets | 26 (35.1%) | 48 (64.9%) |
| **Selection rate** | **7.2%** | **0.11%** |

An orbit-60 net is **~65× more likely** to be a common net than an orbit-120 net.

This enrichment can be understood through several complementary perspectives:

1. **The fold defines a face permutation, and common nets require bijectivity.** When folding with great-dodecahedron angles, each of the 12 faces lands at some position among the 12 great-dodecahedron face planes. This defines a map {1,…,12} → {1,…,12}. A "good" net is one where this map is a bijection. A "bad" net has collisions (the worst case being 6 positions each hit twice).

2. **Symmetry halves the independent constraints.** If the tree has an involution σ, the fold map must commute with σ. The 12 faces split into 6 pairs under σ, and the bijectivity condition reduces from "12 independent images all distinct" to "6 representative images form valid pairs." This roughly squares the probability of success.

3. **Path coherence in symmetric trees.** Each face's final 3D position is determined by cumulative rotations along its root-to-leaf path. In a symmetric tree, faces related by σ traverse "mirror" paths, so their cumulative rotations are related by the same symmetry. This ensures symmetric faces land in symmetrically-related positions rather than independently drifting into collisions.

### Chirality (mirror symmetry)

Under the **rotation subgroup** (order 60, no reflections):
- **148 distinct nets** under rotations only.
- Each of the 74 full-symmetry orbits splits into either:
  - **1 orbit** of size 120 under rotations → the net is **achiral** (equal to its mirror image)
  - **2 orbits** of size 60 under rotations → the net is **chiral** (distinct from its mirror image)

| Rotation orbit size | Count |
|---|---|
| 60 | 96 |
| 30 | 52 |

- If c = number of chiral pairs and a = number of achiral nets:
  - a + c = 74 (full symmetry classes)
  - a + 2c = 148 (rotation-only classes)
  - Solving: **c = 74, a = 0** → **all 74 good nets are chiral**. No common net equals its mirror image.

The 26 nets with orbit size 60 under Ih split into orbits of size 30 under rotations (2 × 26 = 52 rotation-orbits of size 30). The 48 nets with orbit size 120 under Ih split into orbits of size 60 (2 × 48 = 96 rotation-orbits of size 60). Total rotation-orbits: 52 + 96 = 148 ✓.

The chirality of all common nets is related to the asymmetry of the fold operation: `angleToStellate = −2 × dihedral + π` reverses the folding direction compared to flat unfolding, breaking parity.

---

## Implementation: Finding and Visualizing Distinct Good Nets

### Phase 1: Collect good net data — `count_dodecahedron_nets.wls`

Modified `count_dodecahedron_nets.wls` to save the spanning tree edge list for each good net. Output: `output/Dodecahedron/good_nets.txt`, containing 7,320 lines (one per labeled good net). Each line is a Mathematica list of 11 directed `{parent, child}` edge pairs from the fold schedule.

### Phase 2 & 3: Classify good nets — `classify_good_nets.wls`

This script reads the 7,320 good nets and classifies them into equivalence classes under the full icosahedral symmetry group Ih (order 120).

#### Step 1: Generate the symmetry group

The script reuses the Wythoff construction from `count_dodecahedron_nets.wls` to generate the 12 dodecahedron faces and their 3 mirror planes. It then builds all 120 elements of Ih as 3×3 matrices by BFS: starting from the identity matrix, repeatedly multiplying by the 3 reflection matrices `R_i = I − 2nnᵀ/(n·n)` (one per mirror plane) until the group closes at order 120.

#### Step 2: Convert to face permutations

Each 3×3 symmetry matrix is converted to a permutation of {1, …, 12} by applying it to the 12 face centers and matching each transformed center to its nearest original face center.

#### Step 3: Canonicalize

Each good net is represented as an **edge set**: the 11 `{parent, child}` pairs are converted to sorted undirected edges `{min, max}`, then sorted lexicographically. To canonicalize, all 120 permutations are applied to the edge set (permuting face labels), and the **lexicographically smallest** result is taken as the canonical form. Two nets are equivalent iff they have the same canonical form.

#### Step 4: Representative selection

The representative for each equivalence class is the **first net encountered in `good_nets.txt`** whose canonical form defines that class. Since `good_nets.txt` is ordered by the enumeration order of subset IDs and spanning trees, the representative is simply whichever labeled tree in the orbit was found earliest during the Phase 1 enumeration.

#### Output files

| File | Description |
|---|---|
| `good_nets_orbit60.txt` | 26 distinct nets with orbit size 60 (stabilizer order 2) |
| `good_nets_orbit120.txt` | 48 distinct nets with orbit size 120 (trivial stabilizer) |
| `distinct_good_nets.txt` | All 74 representative nets (one per class) |
| `good_nets_classification.txt` | Full classification with orbit sizes and representative indices |

### Phase 4: Visualize — `visualize_all_good_nets.wls`

The script generates one image per distinct good net, rendered as a fully unfolded flat net (the dodecahedron net laid flat in 2D).

#### How it works

1. **Reads** `good_nets_orbit60.txt` (26 nets) and `good_nets_orbit120.txt` (48 nets). Each net is a list of 11 directed `{parent, child}` edge pairs.
2. **Converts** each edge list to a rooted Mathematica `Tree` using `edgeListToTree[edgeList, root]`. This function builds an adjacency list from the edges (treated as undirected), then does a DFS from the root (the first parent vertex in the edge list) to construct the `Tree` object.
3. **Folds** the dodecahedron faces using `buildSchedule` + `foldFaces` with `foldPercent = 1.0` (fully unfolded flat).
4. **Renders** using POVRayRender and saves to the output folder.

#### How to run

From the repo root, on a machine with the `POVRayRender` Mathematica package installed:

```
wolframscript -file AI_assisted_analysis\common_nets_dodecahedron_great_dodecahedron\visualize_all_good_nets.wls
```

#### Output

All 74 images are in `output/common_nets_dodecahedron_great_dodecahedron/`:

| Files | Contents |
|---|---|
| `symmetric_net_01.png` … `symmetric_net_26.png` | 26 nets with 2-fold symmetry (orbit size 60) |
| `asymmetric_net_01.png` … `asymmetric_net_48.png` | 48 nets with trivial symmetry (orbit size 120) |

### Notes

- The 5,184,000 count is consistent with Kirchhoff's theorem applied to the icosahedral graph (dual of dodecahedron face-adjacency).
- "Worst" nets with only 6 unique faces likely correspond to configurations where each great dodecahedron face position is covered by exactly 2 faces (12 faces / 6 positions = 2 per position).
