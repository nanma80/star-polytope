# Symmetric Nets of the Regular Dodecahedron

## Background

The regular dodecahedron has **43,380 distinct nets** (up to the full icosahedral symmetry group Ih of order 120). Of these, **360** have a non-trivial symmetry: each is invariant under exactly one C₂ rotation (a 180° rotation through the midpoints of two opposite edges). The remaining 43,020 nets have no symmetry at all.

For the proof that only C₂ rotations can stabilize a spanning tree, and the derivation of 360 from Burnside's lemma, see the "Orbit structure of all 43,380 dodecahedron nets" section in [`../common_nets_dodecahedron_great_dodecahedron/counting_common_nets_dodecahedron_great_dodecahedron.md`](../common_nets_dodecahedron_great_dodecahedron/counting_common_nets_dodecahedron_great_dodecahedron.md).

## Enumeration — `enumerate_symmetric_nets.wls`

The script enumerates all 360 symmetric nets without brute-forcing the full 5,184,000 labeled spanning trees.

### Algorithm

**Step 1: Build the face-adjacency graph.** Generate the 12 dodecahedron faces via Wythoff construction. Build the adjacency graph: 12 vertices, 30 edges (the icosahedron graph).

**Step 2: Compute the symmetry group.** Generate all 120 elements of Ih as face permutations. Identify the 15 C₂ rotations (order-2 elements with determinant +1 and no fixed faces).

**Step 3: Compute edge orbits under one C₂ rotation.** Pick one representative C₂ rotation. It acts on the 12 faces as 6 transpositions (no fixed points). The 30 edges partition into:
- **2 fixed edge-orbits** (size 1): edges whose endpoints are swapped into each other
- **14 paired edge-orbits** (size 2): pairs of edges related by the rotation

**Step 4: Enumerate invariant spanning trees.** A C₂-invariant spanning tree must be a union of complete edge-orbits totaling 11 edges. With orbits of size 1 and 2:

$$f \times 1 + p \times 2 = 11$$

where f is the number of selected fixed orbits and p the number of selected paired orbits. Since 11 is odd, f must be odd: the only solution with f ≤ 2 is **f = 1, p = 5** (6 edge-orbits, 11 edges). The script enumerates all C(2,1) × C(14,5) = 4,004 combinations and checks which yield a connected spanning tree. This gives **1,440 invariant trees** for this one C₂ rotation, matching Buekenhout and Parker's count.

**Step 5: Expand to all labeled symmetric trees.** Apply all 120 symmetries of Ih to the 1,440 trees to generate all labeled symmetric trees. Since the 15 C₂ rotations each fix 1,440 trees with no overlap, the total is 15 × 1,440 = **21,600 labeled symmetric trees**.

**Step 6: Classify under Ih.** Canonicalize each of the 21,600 trees under Ih (lexicographically smallest image under all 120 permutations). This yields **360 equivalence classes**, each of orbit size 60.

### Verification

| Quantity | Expected | Computed |
|---|---|---|
| C₂ rotations in Ih | 15 | 15 |
| Fixed trees per C₂ | 1,440 | 1,440 |
| Total labeled symmetric trees | 21,600 | 21,600 |
| Distinct symmetric nets | 360 | 360 |
| All orbit sizes | 60 | 60 |

### Output

`symmetric_dodecahedron_nets.txt` — 360 lines, one per distinct net. Each line is a Mathematica list of 11 sorted undirected edges `{a, b}` with a < b.

## Visualization — `visualize_symmetric_nets.wls`

Generates one image per net, rendered as a fully unfolded flat dodecahedron net using POVRayRender.

### How it works

1. Reads `symmetric_dodecahedron_nets.txt` (360 nets).
2. Converts each edge list to a rooted Mathematica `Tree` (the first vertex of the first edge is the root).
3. Unfolds the dodecahedron flat using `buildSchedule` + `foldFaces` with `foldPercent = 1.0`.
4. Uses PCA on the flat vertex coordinates to align the net's longer axis with the canvas's horizontal direction.
5. Renders with POVRayRender.

### How to run

From the repo root:

```
wolframscript -file AI_assisted_analysis\symmetric_nets_dodecahedron\visualize_symmetric_nets.wls
```

### Output

360 images in `output/symmetric_nets_dodecahedron/`:

```
net_001.png … net_360.png
```

## References

- F. Buekenhout, M. Parker, "The Number of Nets of the Regular Convex Polytopes in Dimension ≤ 4," *Discrete Mathematics* 186 (1998), 69–94.
- R. Mabry, "Pyritomania: Nets of Pyritohedra," https://lsusmath.rickmabry.org/rmabry/dodec/pyrito/pyrito1.html
- C. Hippenmeyer, "Die Anzahl der inkongruenten ebenen Netze eines regulären Ikosaeders," *Elem. Math.* 34 (1979), 61–63.
