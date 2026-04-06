#!/usr/bin/env wolframscript

(* Enumerate all 360 symmetric (orbit-60) nets of the regular dodecahedron.
   
   A symmetric net is a spanning tree of the face-adjacency graph that is
   invariant under some non-trivial symmetry. By Buekenhout & Parker (1998),
   the only such symmetries are C2 rotations through opposite edge midpoints.
   
   Strategy:
   1. Build the face-adjacency graph (icosahedron graph, 12 vertices, 30 edges)
   2. Pick one C2 rotation and compute its action on faces
   3. Find the edge orbits under this rotation (2 fixed + 14 paired = 16 orbits)
   4. Build the quotient graph on 6 vertex-orbits with these edge-orbits
   5. Enumerate all spanning trees of the quotient graph (should be 720)
   6. Lift each to a spanning tree of the original graph (720 * 2 = 1440)
   7. Classify under full Ih to get 360 distinct nets
   8. Save representative edge lists
   
   Run from the repo root:
     wolframscript -file AI_assisted_analysis\symmetric_nets_dodecahedron\enumerate_symmetric_nets.wls
*)

(* ---- Utility functions ---- *)

epsilon = 0.00000001;
ApproxSamePoint[point1_, point2_] := Round[point1, epsilon] == Round[point2, epsilon];
sameCenter[set1_, set2_] := ApproxSamePoint[Total[set1], Total[set2]];

HInner[v_, u_, sig_] := If[sig > 0, 2 * v[[1]] * u[[1]] - Dot[v, u], Dot[v, u]];
HReflect[point_, mirror_, sig_] := If[sig != 0,
    point - 2 * HInner[point, mirror, sig]/HInner[mirror, mirror, sig]*mirror,
    point - 2 * (mirror[[2]]*point[[2]] + mirror[[3]]*point[[3]] + mirror[[1]])/(mirror[[2]]^2 + mirror[[3]]^2) * {0, mirror[[2]], mirror[[3]]}
];
HDoubleReflect[point_, mirror1_, mirror2_, sig_] := HReflect[HReflect[point, mirror1, sig], mirror2, sig];

(* ---- Face generation ---- *)

getGenerator[p_, q_] := Module[
    {inner01, inner02, inner12, signature, p0, p1, p2, otherp2, ch2psi, mirror1, mirror2, mirror3},
    inner02 = Cot[Pi/p]*Cot[Pi/q];
    inner12 = Cos[Pi/q]/Sin[Pi/p];
    inner01 = Cos[Pi/p]/Sin[Pi/q];
    signature = Sign[1/2 - 1/p - 1/q];
    p0 = {inner02, Sqrt[signature*(inner02^2 - 1)], 0} // Simplify;
    p1 = {inner12, Sqrt[signature*(inner12^2 - 1)] Cos[Pi/p], Sqrt[signature*(inner12^2 - 1)] Sin[Pi/p]} // Simplify;
    p2 = {1, 0, 0};
    ch2psi = 2*inner12^2 - 1;
    otherp2 = {ch2psi, Sqrt[signature*(ch2psi^2 - 1)] Cos[Pi/p], Sqrt[signature*(ch2psi^2 - 1)] Sin[Pi/p]};
    mirror1 = {0, 0, 1};
    mirror2 = {0, -Sin[Pi/p], Cos[Pi/p]};
    mirror3 = otherp2 - p2 // Simplify;
    {p0, {mirror1, mirror2, mirror3} // N, signature}
];

generateFaces[p_, q_] := Module[
    {orderedFaces, fid, faces, face, generator, vertex1, mirrors, signature, face1, countStart, newFaces, newVertex, finished, centeredMirrors, faceCenter, i, mirrorIndex},
    generator = getGenerator[p, q];
    vertex1 = generator[[1]];
    mirrors = generator[[2]];
    signature = generator[[3]];
    face1 = {vertex1} // N;
    finished = False;
    For[i = 0, i < 20 && finished == False, i++,
        newVertex = FullSimplify[HDoubleReflect[face1[[-1]], mirrors[[1]], mirrors[[2]], signature]];
        If[!(ApproxSamePoint[newVertex, face1[[1]]]),
            AppendTo[face1, newVertex],
            finished = True;
        ]
    ];
    faces = {face1};
    countStart = -1;
    For[i = 0, i <= 4 && countStart != Length[faces], i++,
        countStart = Length[faces];
        For[mirrorIndex = 3, mirrorIndex >= 1, mirrorIndex--,
            newFaces = Map[HReflect[#, mirrors[[mirrorIndex]], signature] &, faces, {2}];
            faces = Union[faces, newFaces, SameTest -> sameCenter];
        ];
    ];
    centeredMirrors = Select[mirrors, #[[1]] == 0 &];
    countStart = -1;
    For[i = 0, i < 20 && countStart != Length[faces], i++,
        countStart = Length[faces];
        For[mirrorIndex = Length[centeredMirrors], mirrorIndex >= 1, mirrorIndex--,
            newFaces = Map[HReflect[#, centeredMirrors[[mirrorIndex]], signature] &, faces, {2}];
            faces = Union[faces, newFaces, SameTest -> sameCenter];
        ];
    ];
    orderedFaces = {};
    For[fid = 1, fid <= Length[faces], fid++,
        face = faces[[fid]];
        faceCenter = Mean[face];
        If[Dot[faceCenter, Cross[face[[1]], face[[2]]]] < 0,
            face = Reverse[face]
        ];
        AppendTo[orderedFaces, face];
    ];
    orderedFaces
];

(* ---- Symmetry group ---- *)

reflectionMatrix[normal_] := IdentityMatrix[3] - 2 * Outer[Times, normal, normal] / Dot[normal, normal];

generateSymmetryGroup[mirrors_] := Module[
    {generators, group, newGroup, g, gen, product, isNew, iter},
    generators = Map[reflectionMatrix, mirrors];
    group = {IdentityMatrix[3]};
    For[iter = 0, iter < 20, iter++,
        newGroup = group;
        Do[
            Do[
                product = g . gen;
                isNew = True;
                Do[
                    If[Max[Abs[product - existing]] < epsilon,
                        isNew = False; Break[];
                    ],
                    {existing, newGroup}
                ];
                If[isNew, AppendTo[newGroup, product]],
                {gen, generators}
            ],
            {g, group}
        ];
        If[Length[newGroup] == Length[group], Break[]];
        group = newGroup;
    ];
    group
];

symmetryToFacePermutation[symMatrix_, faceCenters_] := Module[
    {transformedCenters, tc},
    transformedCenters = Map[symMatrix . # &, faceCenters];
    Table[
        tc = transformedCenters[[i]];
        First[Ordering[Map[Norm[# - tc] &, faceCenters], 1]],
        {i, Length[faceCenters]}
    ]
];

(* ---- Canonicalization ---- *)

applyPermutationToNet[net_, perm_] := Sort[Map[Sort, Map[{perm[[#[[1]]]], perm[[#[[2]]]]} &, net]]];

canonicalizeNet[net_, permutations_] := Module[
    {best, permuted},
    best = Sort[Map[Sort, net]];
    Do[
        permuted = applyPermutationToNet[net, perm];
        If[Order[permuted, best] == 1, best = permuted],
        {perm, permutations}
    ];
    best
];

(* ---- Main ---- *)

Print["=== Step 1: Generate dodecahedron and symmetry group ==="];
faces = generateFaces[5, 3];
faceCenters = Map[Mean, faces] // N;
Print["Faces: ", Length[faces]];

generator = getGenerator[5, 3];
mirrors = generator[[2]];
symmetryMatrices = generateSymmetryGroup[mirrors];
Print["Symmetry group order: ", Length[symmetryMatrices]];

facePermutations = Map[symmetryToFacePermutation[#, faceCenters] &, symmetryMatrices];
uniquePerms = Union[facePermutations];
Print["Unique face permutations: ", Length[uniquePerms]];

(* ---- Step 2: Build face-adjacency graph ---- *)

Print["\n=== Step 2: Build face-adjacency graph ==="];
adjacentFaces[f1_, f2_] := Length[Intersection[f1, f2, SameTest -> ApproxSamePoint]] == 2;
adjMatrix = Table[If[i != j && adjacentFaces[faces[[i]], faces[[j]]], 1, 0], {i, 12}, {j, 12}];
edges = {};
Do[If[adjMatrix[[i, j]] == 1 && i < j, AppendTo[edges, {i, j}]], {i, 12}, {j, 12}];
Print["Edges: ", Length[edges]];

(* ---- Step 3: Find C2 rotations ---- *)

Print["\n=== Step 3: Find C2 rotations ==="];
(* C2 rotations are order-2 elements with det > 0 and no fixed faces *)
c2Perms = {};
c2Indices = {};
Do[
    perm = facePermutations[[i]];
    mat = symmetryMatrices[[i]];
    If[perm != Range[12] &&
       PermutationOrder[FindPermutation[perm]] == 2 &&
       Det[mat] > 0 &&
       Count[Table[perm[[k]] == k, {k, 12}], True] == 0,
        AppendTo[c2Perms, perm];
        AppendTo[c2Indices, i];
    ],
    {i, Length[facePermutations]}
];
Print["C2 rotations found: ", Length[c2Perms]];

(* Pick the first C2 rotation *)
c2Perm = c2Perms[[1]];
Print["Using C2 rotation: ", c2Perm];

(* ---- Step 4: Compute vertex and edge orbits ---- *)

Print["\n=== Step 4: Compute quotient graph ==="];

(* Vertex orbits under c2Perm *)
vertexOrbits = {};
assigned = ConstantArray[0, 12];
Do[
    If[assigned[[v]] == 0,
        orbit = Union[{v, c2Perm[[v]]}];
        AppendTo[vertexOrbits, orbit];
        Do[assigned[[u]] = Length[vertexOrbits], {u, orbit}];
    ],
    {v, 12}
];
Print["Vertex orbits: ", vertexOrbits];
Print["Number of vertex orbits: ", Length[vertexOrbits]];

(* Map each vertex to its orbit index *)
vertexToOrbit = assigned;

(* Edge orbits under c2Perm *)
edgeOrbits = {};
edgeAssigned = ConstantArray[0, Length[edges]];
Do[
    If[edgeAssigned[[ei]] == 0,
        e = edges[[ei]];
        mappedEdge = Sort[{c2Perm[[e[[1]]]], c2Perm[[e[[2]]]]}];
        mappedIdx = FirstPosition[edges, mappedEdge][[1]];
        orbit = Union[{ei, mappedIdx}];
        AppendTo[edgeOrbits, orbit];
        Do[edgeAssigned[[idx]] = Length[edgeOrbits], {idx, orbit}];
    ],
    {ei, Length[edges]}
];

fixedEdgeOrbits = Select[edgeOrbits, Length[#] == 1 &];
pairedEdgeOrbits = Select[edgeOrbits, Length[#] == 2 &];
Print["Edge orbits: ", Length[edgeOrbits], " (", Length[fixedEdgeOrbits], " fixed, ", Length[pairedEdgeOrbits], " paired)"];

(* Build quotient graph: vertices are vertex-orbits, edges are edge-orbits *)
(* Each edge-orbit connects the vertex-orbits of its endpoints *)
quotientEdges = Table[
    e = edges[[edgeOrbits[[oi, 1]]]];
    Sort[{vertexToOrbit[[e[[1]]]], vertexToOrbit[[e[[2]]]]}],
    {oi, Length[edgeOrbits]}
];
Print["Quotient edges: ", quotientEdges];

nQuotientVerts = Length[vertexOrbits];
quotientGraph = Graph[Range[nQuotientVerts],
    Table[UndirectedEdge[quotientEdges[[i, 1]], quotientEdges[[i, 2]]], {i, Length[quotientEdges]}]];
Print["Quotient graph: ", nQuotientVerts, " vertices, ", EdgeCount[quotientGraph], " edges"];

(* ---- Step 5: Enumerate symmetric spanning trees ---- *)

Print["\n=== Step 5: Enumerate symmetric spanning trees ==="];

(* A C2-invariant spanning tree has 11 edges. Each edge-orbit contributes
   either 1 edge (fixed) or 2 edges (paired). With 2 fixed and 14 paired orbits:
   f*1 + p*2 = 11, so f must be odd => f=1, p=5 (6 edge-orbits total).
   We select 1 of 2 fixed orbits and 5 of 14 paired orbits, then check
   if the resulting 11 edges form a spanning tree of the original graph. *)

fixedOrbitIndices = Flatten[Position[Map[Length, edgeOrbits], 1]];
pairedOrbitIndices = Flatten[Position[Map[Length, edgeOrbits], 2]];
Print["Fixed edge-orbits: ", Length[fixedOrbitIndices], ", Paired: ", Length[pairedOrbitIndices]];

allSymmetricTrees = {};
Do[
    Do[
        selectedOrbits = Join[{fixedOrbitIndices[[fi]]}, pairedOrbitIndices[[pairedSubset]]];
        selectedEdges = Flatten[edgeOrbits[[#]] & /@ selectedOrbits];
        edgeList = edges[[selectedEdges]];
        
        g = Graph[Range[12], UndirectedEdge @@@ edgeList];
        If[ConnectedGraphQ[g] && EdgeCount[g] == 11,
            sorted = Sort[Map[Sort, edgeList]];
            If[!MemberQ[allSymmetricTrees, sorted],
                AppendTo[allSymmetricTrees, sorted];
            ];
        ],
        {pairedSubset, Subsets[Range[Length[pairedOrbitIndices]], {5}]}
    ],
    {fi, Length[fixedOrbitIndices]}
];
Print["Symmetric spanning trees from this C2 rotation: ", Length[allSymmetricTrees]];

(* ---- Step 6: Collect all labeled symmetric trees ---- *)

Print["\n=== Step 6: Collect all labeled symmetric trees ==="];
allLabeledSet = <||>;
Do[
    tree = allSymmetricTrees[[ti]];
    Do[
        mappedTree = Sort[Map[Sort[{perm[[#[[1]]]], perm[[#[[2]]]]}] &, tree]];
        key = ToString[mappedTree];
        If[!KeyExistsQ[allLabeledSet, key],
            allLabeledSet[key] = mappedTree;
        ],
        {perm, uniquePerms}
    ];
    If[Mod[ti, 100] == 0, Print["Expanded ", ti, " / ", Length[allSymmetricTrees], " trees, total labeled: ", Length[allLabeledSet]]],
    {ti, Length[allSymmetricTrees]}
];
allLabeled = Values[allLabeledSet];
Print["Total labeled symmetric trees: ", Length[allLabeled]];

(* ---- Step 7: Classify under full Ih ---- *)

Print["\n=== Step 7: Classify into equivalence classes ==="];

canonicalMap = <||>;
Do[
    net = allLabeled[[i]];
    canon = canonicalizeNet[net, uniquePerms];
    canonKey = ToString[canon];
    If[KeyExistsQ[canonicalMap, canonKey],
        AppendTo[canonicalMap[canonKey], i],
        canonicalMap[canonKey] = {i};
    ];
    If[Mod[i, 1000] == 0,
        Print["Classified ", i, " / ", Length[allLabeled], ", distinct: ", Length[canonicalMap]];
    ],
    {i, Length[allLabeled]}
];

Print["\n=== Results ==="];
Print["Total labeled symmetric trees: ", Length[allLabeled]];
Print["Distinct symmetric nets: ", Length[canonicalMap]];

orbitSizes = Map[Length, Values[canonicalMap]];
Print["Orbit sizes: ", Sort[Tally[orbitSizes]]];
Print["Sum of orbit sizes: ", Total[orbitSizes]];

(* ---- Save results ---- *)

baseFolder = FileNameJoin[{"AI_assisted_analysis", "symmetric_nets_dodecahedron"}];

(* Save all 360 representative nets *)
outputFile = FileNameJoin[{baseFolder, "symmetric_dodecahedron_nets.txt"}];
stream = OpenWrite[outputFile, PageWidth -> Infinity];

(* Convert each representative to directed edge list format (matching good_nets format) *)
representatives = {};
Do[
    members = Values[canonicalMap][[i]];
    rep = members[[1]];
    tree = allLabeled[[rep]];
    AppendTo[representatives, tree];
    Write[stream, tree],
    {i, Length[canonicalMap]}
];
Close[stream];
Print["\n", Length[canonicalMap], " representative symmetric nets saved to ", outputFile];

Print["\nDone!"];
