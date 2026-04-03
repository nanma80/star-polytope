# Counting Common Nets of the Dodecahedron and the Great Dodecahedron

## Problem Statement

A **net** of a polyhedron is a planar arrangement of its faces obtained by cutting along edges and unfolding to a flat shape. For a dodecahedron (12 pentagonal faces, 30 edges, 20 vertices), every net corresponds to a **spanning tree** of the dual graph of edges-between-faces (the icosahedral/dodecahedral adjacency graph). A spanning tree selects 11 of the 30 edges as "fold edges" (hinges); the remaining 19 edges are cut.

The regular dodecahedron {5, 3} and the great dodecahedron {5, 5/2} share the same face shape (regular pentagons) and the same number of faces (12). They differ in how faces are arranged: the dihedral angle of the great dodecahedron causes faces to interpenetrate.

### The question

Given a net (spanning tree) of the dodecahedron, we can fold it in two ways:

1. **Fold to dodecahedron**: use the dodecahedral dihedral angle (~116.57°). Every spanning tree folds back into the dodecahedron — by construction.
2. **Fold to great dodecahedron**: instead of the dodecahedral dihedral angle, use the great dodecahedral dihedral angle at each hinge. This causes faces to intersect. Sometimes all 12 distinct face positions of the great dodecahedron are covered; sometimes faces collide (two or more faces land on the same position), leaving fewer than 12 distinct positions covered.

A net is a **"good net"** (common net) if the second folding covers all 12 faces of the great dodecahedron. Such a net is a **common net** of both the dodecahedron and the great dodecahedron.

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

The well-known count of **43,380 distinct nets** for the regular dodecahedron is obtained by quotienting out the symmetry group.

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

### Distinct good nets

For good nets:
- Labeled count: **7,320**
- 7,320 / 120 = **61 exactly**
- This exact divisibility means **no good net spanning tree is fixed by any non-trivial symmetry** — every good net orbit has exactly 120 elements.
- Therefore: **61 distinct good nets** (up to full icosahedral symmetry, including reflections).

The comment in the script confirms: 43,200 / 61 ≈ 708.2 (ratio of distinct spanning trees to distinct good nets).

### Chirality (mirror symmetry)

If we only quotient by the **rotation subgroup** (order 60, no reflections):
- 7,320 / 60 = **122** labeled orbits under rotations alone.
- Each of the 61 full-symmetry orbits splits into either:
  - **1 orbit** of size 120 under rotations: the net is **achiral** (equal to its mirror image) → counted once
  - **2 orbits** of size 60 under rotations: the net is **chiral** (distinct from its mirror image) → counted as a chiral pair

- If c = number of chiral pairs and a = number of achiral nets, then:
  - a + c = 61 (full symmetry classes)
  - a + 2c = 122 (rotation-only classes)
  - Solving: c = 61, a = 0 → **all 61 good nets are chiral** (OR some might be achiral, reducing the rotation-only count below 122)
  
  Actually: since a + 2c = 122 and a + c = 61, we get c = 61 and a = 0. This would mean all good nets are chiral — none is equal to its mirror image. This needs verification.

## Implementation Plan: Finding and Visualizing Distinct Good Nets

### Phase 1: Collect good net data

Modify `count_dodecahedron_nets.wls` to save the spanning tree edge list for each good net to a file. The output should be a machine-readable list of the 7,320 good net spanning trees.

### Phase 2: Compute symmetry group permutations

Compute the 120 elements of the icosahedral symmetry group as permutations of the 12 face labels:
1. Generate the 12 face centers from the dodecahedron.
2. For each symmetry (rotation/reflection matrix), determine which face maps to which → a permutation.
3. Store all 120 permutations.

### Phase 3: Canonicalize and classify

For each good net spanning tree (a set of 11 edges, where each edge is a pair {i,j} of face indices):
1. Apply each of the 120 permutations to the edge set.
2. Sort the resulting edge set lexicographically.
3. The **canonical form** is the lexicographically smallest result.
4. Two good nets with the same canonical form are equivalent.

### Phase 4: Visualize

For each of the (expected) 61 equivalence classes:
1. Select one representative spanning tree.
2. Unfold the dodecahedron according to that tree → 2D net.
3. Render the net (both as dodecahedron net and showing the great dodecahedron folding).

### Notes

- The 5,184,000 count is consistent with Kirchhoff's theorem applied to the icosahedral graph (dual of dodecahedron face-adjacency).
- "Worst" nets with only 6 unique faces likely correspond to configurations where each great dodecahedron face position is covered by exactly 2 faces (12 faces / 6 positions = 2 per position).
