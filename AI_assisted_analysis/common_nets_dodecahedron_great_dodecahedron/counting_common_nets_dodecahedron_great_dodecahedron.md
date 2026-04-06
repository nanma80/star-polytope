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

$$\text{\# spanning trees} = \frac{1}{12} (5+\sqrt{5})^3 \cdot 6^5 \cdot (5-\sqrt{5})^3 = \frac{1}{12} \cdot 20^3 \cdot 7776 = 5{,}184{,}000$$

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

$$\text{\# distinct nets} = \frac{1}{|G|} \sum_{g \in G} |\text{Fix}(g)|$$

where Fix(g) is the number of spanning trees invariant under symmetry g.

- Simple division: 5,184,000 / 120 = 43,200
- Burnside gives: **43,380**
- The difference of 180 comes from spanning trees that are invariant under some non-identity symmetry. These trees have orbits of size < 120, so they contribute "extra" to the orbit count.
- Equivalently: Σ_{g≠e} |Fix(g)| = 43,380 × 120 − 5,184,000 = **21,600** total extra fixed points from non-trivial symmetries.

### Orbit structure of all 43,380 dodecahedron nets

The possible orbit sizes for spanning trees are constrained by the structure of Ih and the fact that a spanning tree has 11 edges. The only possible orbit sizes are **60** and **120** — no others, and the 360 symmetric nets all have a C₂ rotational symmetry (never a reflection).

This was first established by Buekenhout and Parker (1998), who proved three key results (Section 5.6 of their paper):

**Lemma 5.6.1** (only order-2 rotations can stabilize a tree): If a non-identity symmetry g fixes a spanning tree, then g has order 2 and has no fixed vertices (Fix g = ∅). The proof rules out order 3 and 5 by noting that a fixed edge implies a fixed vertex, which acts on the pentagonal vertex-figure and forces g to have order 2, a contradiction. It then rules out order-2 elements with fixed vertices: such an element fixes exactly 4 vertices, forming a disconnected subgraph, which contradicts the requirement (their Lemma 3.5) that the fixed-point set of a tree-stabilizing symmetry be connected. Since Fix g = ∅ means no fixed vertices, g must be a rotation (not a reflection), specifically a C₂ rotation through opposite edge midpoints.

**Lemma 5.6.2** (counting fixed trees): All such order-2 rotations are conjugate in Ih. There are |C_g| = 15 of them, and each fixes |σ_g| = 1,440 spanning trees. The 1,440 is computed via a quotient graph: under a C₂ rotation, the 30 edges split into 2 invariant edges and 4 orbits of size 2. The quotient graph Q(F, g) has 720 spanning trees, and each gives 2 spanning trees of the original graph (from a choice at the invariant edges), yielding 1,440.

**Proposition 5.6.3** (Burnside's lemma): The number of distinct nets is:

$$u(F) = \frac{1}{120}(120 \times 43{,}200 + 15 \times 1{,}440) = 43{,}380$$

where 43,200 = 5,184,000 / 120 is the identity's contribution.

The orbit-size decomposition follows immediately (though Buekenhout and Parker did not write it out): the 15 × 1,440 = 21,600 non-identity fixed points correspond to 21,600 / 60 = **360** orbit-60 nets, each stabilized by exactly one C₂ rotation. The remaining 43,380 − 360 = **43,020** nets have trivial stabilizer (orbit size 120). Mabry later stated the number 360 explicitly in the context of pyritohedra, deriving it independently from the formula 216,810 = 5 × 43,380 − 2 × 360 for pyritohedron nets.

More broadly, **no improper symmetry** (orientation-reversing element) fixes any spanning tree. Lemma 5.6.1 rules out reflections (which fix 2 vertices, contradicting Fix g = ∅). The inversion is ruled out separately: it swaps all 12 faces in 6 non-adjacent pairs, giving all edge orbits size 2, and 11 (odd) cannot be a sum of 2s. Together, these imply that **all 43,380 dodecahedron nets are chiral** (none equals its mirror image). Under the rotation subgroup (order 60), every full-symmetry orbit of size 120 splits into two orbits of size 60 (a chiral pair), and every orbit of size 60 splits into two orbits of size 30.

| Orbit size | Stabilizer | Count | Labeled trees |
|---|---|---|---|
| 120 | trivial | 43,020 (99.17%) | 43,020 × 120 = 5,162,400 |
| 60 | C₂ rotation | 360 (0.83%) | 360 × 60 = 21,600 |
| **Total** | | **43,380** | **5,184,000** |

**References:**
- F. Buekenhout, M. Parker, "The Number of Nets of the Regular Convex Polytopes in Dimension ≤ 4," *Discrete Mathematics* 186 (1998), 69–94.
- R. Mabry, "Pyritomania: Nets of Pyritohedra," https://lsusmath.rickmabry.org/rmabry/dodec/pyrito/pyrito1.html

### Orbit structure of the 74 common nets

Computation (see `classify_good_nets.wls`) reveals **74 distinct common nets**:

| Orbit size | Stabilizer | Count | Labeled trees |
|---|---|---|---|
| 120 | trivial | 48 (64.9%) | 48 × 120 = 5,760 |
| 60 | C₂ rotation | 26 (35.1%) | 26 × 60 = 1,560 |
| **Total** | | **74** | **7,320** |

The naïve estimate of 7,320 / 120 = 61 distinct nets is wrong because exact divisibility of the labeled count by the group order is a necessary but not sufficient condition for all orbits to have full size. The coincidence masked 26 smaller orbits.

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

### Chirality

Since all 43,380 dodecahedron nets are chiral (see above), all 74 common nets are chiral as well. Under the rotation subgroup (order 60), each Ih orbit splits into two rotation-orbits: the 48 orbit-120 nets split into 96 rotation-orbits of size 60, and the 26 orbit-60 nets split into 52 rotation-orbits of size 30. Total: 148 distinct common nets under rotations only.

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
