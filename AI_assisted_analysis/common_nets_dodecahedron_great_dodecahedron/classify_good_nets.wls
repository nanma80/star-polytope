#!/usr/bin/env wolframscript

(* Phase 2+3: Classify the 7320 good nets into equivalence classes
   under the full icosahedral symmetry group (order 120).
   
   1. Generate dodecahedron faces (reusing Wythoff construction)
   2. Compute the 120 icosahedral symmetries as face permutations
   3. Read good_nets.txt
   4. Canonicalize each net and count distinct classes
*)

(* ---- Utility functions (from count_dodecahedron_nets.wls) ---- *)

epsilon = 0.00000001;
ApproxSamePoint[point1_, point2_] := Round[point1, epsilon] == Round[point2, epsilon];
sameCenter[set1_, set2_] := ApproxSamePoint[Total[set1], Total[set2]];

HInner[v_, u_, sig_] := If[sig > 0, 2 * v[[1]] * u[[1]] - Dot[v, u], Dot[v, u]];
HNormSquare[v_, sig_] := HInner[v, v, sig];
HNorm[v_, sig_] := Sqrt[HNormSquare[v, sig]];
HReflect[point_, mirror_, sig_] := If[sig != 0,
    point - 2 * HInner[point, mirror, sig]/HInner[mirror, mirror, sig]*mirror,
    point - 2 * (mirror[[2]]*point[[2]] + mirror[[3]]*point[[3]] + mirror[[1]])/(mirror[[2]]^2 + mirror[[3]]^2) * {0, mirror[[2]], mirror[[3]]}
];
HDoubleReflect[point_, mirror1_, mirror2_, sig_] := HReflect[HReflect[point, mirror1, sig], mirror2, sig];

(* ---- Face generation (from count_dodecahedron_nets.wls) ---- *)

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
    {orderedFaces, fid, faces, face, generator, vertex1, mirrors, signature, face1, countStart, newFaces, newVertex, finished, centeredMirrors, faceCenter},
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
    Print["Each face contains " <> IntegerString[Length[face1]] <> " vertices."];

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

    Print["Number of faces: " <> IntegerString[Length[orderedFaces]]];
    orderedFaces
];

(* ---- Phase 2: Compute symmetry group as face permutations ---- *)

reflectionMatrix[normal_] := IdentityMatrix[3] - 2 * Outer[Times, normal, normal] / Dot[normal, normal];

generateSymmetryGroup[mirrors_] := Module[
    {generators, group, newGroup, g, gen, product, isNew, iter},

    generators = Map[reflectionMatrix, mirrors];
    group = {IdentityMatrix[3]};

    (* BFS: repeatedly multiply by generators until group closes *)
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
        Print["Symmetry group generation iteration " <> IntegerString[iter] <> ", size: " <> IntegerString[Length[group]]];
    ];
    group
];

symmetryToFacePermutation[symMatrix_, faceCenters_] := Module[
    {perm, transformedCenters, tc, bestMatch},
    transformedCenters = Map[symMatrix . # &, faceCenters];
    perm = Table[
        tc = transformedCenters[[i]];
        bestMatch = First[Ordering[Map[Norm[# - tc] &, faceCenters], 1]];
        bestMatch,
        {i, Length[faceCenters]}
    ];
    perm
];

(* ---- Phase 3: Read nets, canonicalize, classify ---- *)

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

Print["=== Phase 2: Generating dodecahedron and symmetry group ==="];

faces = generateFaces[5, 3];
faceCenters = Map[Mean, faces] // N;
Print["Face centers computed: " <> IntegerString[Length[faceCenters]]];

generator = getGenerator[5, 3];
mirrors = generator[[2]];

Print["Generating full icosahedral symmetry group..."];
symmetryMatrices = generateSymmetryGroup[mirrors];
Print["Symmetry group order: " <> IntegerString[Length[symmetryMatrices]]];

Print["Converting to face permutations..."];
facePermutations = Map[symmetryToFacePermutation[#, faceCenters] &, symmetryMatrices];

(* Verify: all permutations should be valid (each is a permutation of 1..12) *)
validPerms = Select[facePermutations, Sort[#] == Range[12] &];
Print["Valid permutations: " <> IntegerString[Length[validPerms]] <> " / " <> IntegerString[Length[facePermutations]]];
If[Length[validPerms] != 120,
    Print["ERROR: Expected 120 permutations, got " <> IntegerString[Length[validPerms]]];
    Exit[1];
];

(* Remove duplicate permutations if any *)
uniquePerms = Union[facePermutations];
Print["Unique permutations: " <> IntegerString[Length[uniquePerms]]];

Print["=== Phase 3: Reading and classifying good nets ==="];

goodNetFile = FileNameJoin[{"output", "Dodecahedron", "good_nets.txt"}];
lines = ReadList[goodNetFile, Expression];
Print["Good nets read: " <> IntegerString[Length[lines]]];

Print["Canonicalizing nets (this may take a moment)..."];
canonicalForms = {};
canonicalMap = <||>;  (* canonical form -> list of original indices *)

Do[
    net = lines[[i]];
    canon = canonicalizeNet[net, uniquePerms];
    canonKey = ToString[canon];
    If[KeyExistsQ[canonicalMap, canonKey],
        AppendTo[canonicalMap[canonKey], i],
        canonicalMap[canonKey] = {i};
    ];
    If[Mod[i, 500] == 0,
        Print["Processed " <> IntegerString[i] <> " / " <> IntegerString[Length[lines]] <> 
              ", distinct so far: " <> IntegerString[Length[canonicalMap]]];
    ],
    {i, Length[lines]}
];

Print[""];
Print["=== Results ==="];
Print["Total good nets (labeled): " <> IntegerString[Length[lines]]];
Print["Distinct good nets (up to full Ih symmetry): " <> IntegerString[Length[canonicalMap]]];

orbitSizes = Map[Length, Values[canonicalMap]];
Print["Orbit sizes: " <> ToString[Sort[Tally[orbitSizes], #1[[1]] < #2[[1]] &]]];
Print["Sum of orbit sizes: " <> IntegerString[Total[orbitSizes]]];

(* Check for nets with orbits < 120 (fixed by non-trivial symmetry) *)
smallOrbits = Select[orbitSizes, # < 120 &];
If[Length[smallOrbits] > 0,
    Print["WARNING: " <> IntegerString[Length[smallOrbits]] <> " nets have orbits smaller than 120"];
    Print["These nets are fixed by some non-trivial symmetry"],
    Print["All orbits have size 120 — no net is fixed by any non-trivial symmetry"];
];

(* Save representative nets *)
outputFile = FileNameJoin[{"output", "Dodecahedron", "distinct_good_nets.txt"}];
stream = OpenWrite[outputFile, PageWidth -> Infinity];
Do[
    rep = Values[canonicalMap][[i]][[1]];
    Write[stream, lines[[rep]]],
    {i, Length[canonicalMap]}
];
Close[stream];
Print["Representative nets saved to " <> outputFile];

(* Also save canonical forms with orbit info *)
infoFile = FileNameJoin[{"output", "Dodecahedron", "good_nets_classification.txt"}];
stream = OpenWrite[infoFile, PageWidth -> Infinity];
Do[
    key = Keys[canonicalMap][[i]];
    members = canonicalMap[[key]];
    rep = members[[1]];
    WriteLine[stream, "Class " <> IntegerString[i] <> ": orbit size " <> IntegerString[Length[members]] <> ", representative index " <> IntegerString[rep]];
    Write[stream, lines[[rep]]],
    {i, Length[canonicalMap]}
];
Close[stream];
Print["Classification details saved to " <> infoFile];

(* Chirality check: count orbits under rotation subgroup only (order 60) *)
Print[""];
Print["=== Chirality analysis ==="];
rotationPerms = Select[facePermutations, Det[symmetryMatrices[[First[Position[facePermutations, #]][[1]]]]] > 0 &];
Print["Rotation permutations (det > 0): " <> IntegerString[Length[rotationPerms]]];

rotationCanonicalMap = <||>;
Do[
    net = lines[[i]];
    best = Sort[Map[Sort, net]];
    Do[
        permuted = applyPermutationToNet[net, perm];
        If[Order[permuted, best] == 1, best = permuted],
        {perm, rotationPerms}
    ];
    canonKey = ToString[best];
    If[KeyExistsQ[rotationCanonicalMap, canonKey],
        AppendTo[rotationCanonicalMap[canonKey], i],
        rotationCanonicalMap[canonKey] = {i};
    ],
    {i, Length[lines]}
];

Print["Distinct nets under rotations only: " <> IntegerString[Length[rotationCanonicalMap]]];
rotOrbitSizes = Map[Length, Values[rotationCanonicalMap]];
Print["Rotation orbit sizes: " <> ToString[Sort[Tally[rotOrbitSizes], #1[[1]] < #2[[1]] &]]];

nFull = Length[canonicalMap];
nRot = Length[rotationCanonicalMap];
nChiral = nRot - nFull;
nAchiral = nFull - nChiral;
Print["Chiral pairs: " <> IntegerString[nChiral]];
Print["Achiral nets: " <> IntegerString[nAchiral]];
