#!/usr/bin/env wolframscript

(* Visualize all 74 distinct good nets of the dodecahedron/great dodecahedron.
   Reads the two net list files (orbit60 and orbit120) and generates one image per net.
   
   Usage: wolframscript -file visualize_all_good_nets.wls
   
   Output:
     AI_assisted_analysis/good_net_images_orbit60/  (26 images)
     AI_assisted_analysis/good_net_images_orbit120/ (48 images)
*)

p = 5; q = 3; r = 1;

imageSize = {4, 3} * 2160 / 3;
lightSource = {50, -50, 50};
lighting = {{"Point", White, lightSource}};

allColors = Join[{Lighter[Blue, 0.3], Lighter[Green, 0.4], Orange, Green, Yellow, Cyan, Magenta, Brown, Pink, Red, Blue, Darker[Purple, 0.4]}, RandomColor[100]];

norm = 1.0;

Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

(* ---- Utility functions (from unfold_great_dodec_top_view.wls) ---- *)

epsilon = 0.00000001;
ApproxSamePoint[point1_, point2_] := Round[point1, epsilon] == Round[point2, epsilon];
sameCenter[set1_, set2_] := ApproxSamePoint[Total[set1], Total[set2]];
sameEdge[e1_, e2_] := sameCenter[e1, e2];
getEdgesFromFace[face_] := Table[{face[[i + 1]], face[[Mod[i + 1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];
scale[edge_, ratio_] := Module[{center}, center = Mean[edge]; Map[(# - center)*ratio + center &, edge]];
normalize[v_, n_] := v/Norm[v]*n;

HInner[v_, u_, sig_] := If[sig > 0, 2*v[[1]]*u[[1]] - Dot[v, u], Dot[v, u]];
HNormSquare[v_, sig_] := HInner[v, v, sig];
HNorm[v_, sig_] := Sqrt[HNormSquare[v, sig]];
HReflect[point_, mirror_, sig_] := If[sig != 0,
    point - 2*HInner[point, mirror, sig]/HInner[mirror, mirror, sig]*mirror,
    point - 2*(mirror[[2]]*point[[2]] + mirror[[3]]*point[[3]] + mirror[[1]])/(mirror[[2]]^2 + mirror[[3]]^2)*{0, mirror[[2]], mirror[[3]]}
];
HDoubleReflect[point_, mirror1_, mirror2_, sig_] := HReflect[HReflect[point, mirror1, sig], mirror2, sig];

scaleFace[face_, stellationLevel_] := Module[
    {ratio, edges, edgeOrders},
    ratio = Tan[stellationLevel Pi/p]/Tan[Pi/p];
    edges = Map[scale[#, ratio] &, getEdgesFromFace[face]];
    edgeOrders = Table[Mod[stellationLevel*k, p] + 1, {k, 0, p - 1}];
    Flatten[edges[[edgeOrders]], 1]
];

(* ---- Face generation ---- *)

getGenerator[pp_, qq_] := Module[
    {inner01, inner02, inner12, signature, p0, p1, p2, otherp2, ch2psi, mirror1, mirror2, mirror3},
    inner02 = Cot[Pi/pp]*Cot[Pi/qq];
    inner12 = Cos[Pi/qq]/Sin[Pi/pp];
    inner01 = Cos[Pi/pp]/Sin[Pi/qq];
    signature = Sign[1/2 - 1/pp - 1/qq];
    p0 = {inner02, Sqrt[signature*(inner02^2 - 1)], 0} // Simplify;
    p1 = {inner12, Sqrt[signature*(inner12^2 - 1)] Cos[Pi/pp], Sqrt[signature*(inner12^2 - 1)] Sin[Pi/pp]} // Simplify;
    p2 = {1, 0, 0};
    ch2psi = 2*inner12^2 - 1;
    otherp2 = {ch2psi, Sqrt[signature*(ch2psi^2 - 1)] Cos[Pi/pp], Sqrt[signature*(ch2psi^2 - 1)] Sin[Pi/pp]};
    mirror1 = {0, 0, 1};
    mirror2 = {0, -Sin[Pi/pp], Cos[Pi/pp]};
    mirror3 = otherp2 - p2 // Simplify;
    {p0, {mirror1, mirror2, mirror3} // N, signature}
];

generateFaces[pp_, qq_] := Module[
    {orderedFaces, fid, faces, face, generator, vertex1, mirrors, signature, face1, countStart, newFaces, newVertex, finished, centeredMirrors, faceCenter, i, mirrorIndex},
    generator = getGenerator[pp, qq];
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

(* ---- Tree building and folding ---- *)

buildSchedule[t_, schedule_, level_] := Module[
    {subtrees, subtreeId, newSchedule, subtree, subtreeAllData},
    newSchedule = schedule;
    subtrees = TreeChildren[t];
    For[subtreeId = 1, subtreeId <= Length[subtrees], subtreeId++,
        subtree = subtrees[[subtreeId]];
        subtreeAllData = Map[#[[1]] &, VertexList[TreeGraph[subtree]]];
        newSchedule = Append[newSchedule, {TreeData[t], TreeData[subtree], level, subtreeAllData}];
        newSchedule = buildSchedule[subtree, newSchedule, level + 1];
    ];
    newSchedule
];

foldFaces[faces_, rotationSchedule_, foldPercents_] := Module[
    {originalDihedralAngle, rotatedFaces, scheduleId, level, schedule, face1Id, face2Id, rotatedFaceIds,
     face1, face2, pivot, faceCenter1, faceCenter2, pivotCenter, relativeFace1, relativeFace2,
     angleToFlat, angleToStellate, perc, angleToTarget, rotMatrix, fid, faceId, rotatedFace},
    originalDihedralAngle = 0;
    rotatedFaces = faces;
    For[scheduleId = 1, scheduleId <= Length[rotationSchedule], scheduleId++,
        schedule = rotationSchedule[[scheduleId]];
        level = schedule[[3]];
        If[level >= 1,
            face1Id = schedule[[1]];
            face2Id = schedule[[2]];
            rotatedFaceIds = schedule[[4]];
            face1 = rotatedFaces[[face1Id]];
            face2 = rotatedFaces[[face2Id]];
            pivot = Intersection[face1, face2, SameTest -> ApproxSamePoint];
            If[Length[pivot] != 2,
                Print["Unexpected error. Cannot find correct pivot for schedule:"];
                Print[schedule];
                Print["pivot: ", pivot];
                Return[rotatedFaces];
            ];
            faceCenter1 = Mean[face1];
            faceCenter2 = Mean[face2];
            pivotCenter = Mean[pivot];
            relativeFace1 = faceCenter1 - pivotCenter;
            relativeFace2 = faceCenter2 - pivotCenter;
            originalDihedralAngle = ArcCos[Dot[relativeFace1, relativeFace2]/Norm[relativeFace1]/Norm[relativeFace2]];
            angleToFlat = Pi - originalDihedralAngle;
            angleToStellate = -2*originalDihedralAngle + Pi;
            perc = foldPercents[[level]];
            angleToTarget = If[perc >= 0, angleToFlat, angleToStellate];
            rotMatrix = RotationMatrix[angleToTarget*Abs[perc], {relativeFace2, relativeFace1}];
            For[fid = 1, fid <= Length[rotatedFaceIds], fid++,
                faceId = rotatedFaceIds[[fid]];
                rotatedFace = rotatedFaces[[faceId]];
                rotatedFace = Map[((# - pivotCenter).rotMatrix + pivotCenter) &, rotatedFace];
                rotatedFaces[[faceId]] = rotatedFace;
            ];
        ];
    ];
    rotatedFaces
];

elements3D[faces_, stellationLevel_, spinAngle_, flipAngle_, sig_, range_, rootFC_] := Module[
    {allEdges, edges, allVertices, vertices, selectedFaces, elements, graph,
     staticOrientation, rotation, faceCentersLocal, viewCenter, thickness, opacity},
    staticOrientation = RotationMatrix[{rootFC, {0, 0, -1}}];
    rotation = RotationMatrix[flipAngle, {-1, -1, 0}].RotationMatrix[spinAngle, {0, 0, 1}].staticOrientation;
    selectedFaces = Map[(rotation.#) &, faces, {2}];
    selectedFaces = Map[scaleFace[#, r] &, selectedFaces];
    allEdges = Flatten[Map[getEdgesFromFace, selectedFaces], 1];
    edges = Union[allEdges, SameTest -> sameEdge];
    faceCentersLocal = Map[Mean, selectedFaces];
    allVertices = Flatten[edges, 1];
    vertices = Union[allVertices, SameTest -> ApproxSamePoint];
    viewCenter = Mean[faceCentersLocal];
    thickness = 0.01*range;
    opacity = 1;
    elements = {
        Table[{
            Opacity[opacity], FaceForm[allColors[[k]]], Polygon[selectedFaces[[k]]*(1 + 0.0001 k)]
        }, {k, Length[selectedFaces]}],
        {Opacity[1], FaceForm[White], Map[Cylinder[#, thickness] &, edges]},
        {Opacity[1], FaceForm[White], Map[Sphere[#, thickness*1.5] &, vertices]}
    };
    graph = Graphics3D[
        elements,
        ViewPoint -> {0, 0, 100},
        ViewVertical -> {1, 0, 0},
        PlotRange -> {{viewCenter[[1]] - range, viewCenter[[1]] + range},
                      {viewCenter[[2]] - range, viewCenter[[2]] + range},
                      {viewCenter[[3]] - range, viewCenter[[3]] + range}},
        Lighting -> lighting
    ];
    graph
];

(* ---- Convert edge list to Mathematica Tree ---- *)

edgeListToTree[edgeList_, root_] := Module[
    {adj, visited, buildSubtree},
    (* Build adjacency list from directed {parent, child} edges, treating as undirected *)
    adj = <||>;
    Do[
        {u, v} = e;
        If[!KeyExistsQ[adj, u], adj[u] = {}];
        If[!KeyExistsQ[adj, v], adj[v] = {}];
        AppendTo[adj[u], v];
        AppendTo[adj[v], u],
        {e, edgeList}
    ];
    visited = <||>;
    buildSubtree[node_] := Module[{children},
        visited[node] = True;
        children = Select[adj[node], !KeyExistsQ[visited, #] &];
        If[Length[children] == 0,
            node,
            Tree[node, Map[buildSubtree, children]]
        ]
    ];
    buildSubtree[root]
];

(* ---- Render one net ---- *)

renderNet[faces_, edgeList_, netIndex_, outputFolder_] := Module[
    {root, tree, rootFaceCenter, rotationSchedule, maxLevel, foldPercents,
     rotatedFaces, range, spinAngle, flipAngle, graph, outputFileName},

    (* Root at the first vertex mentioned in the edge list *)
    root = edgeList[[1]][[1]];
    tree = edgeListToTree[edgeList, root];

    rootFaceCenter = Mean[faces[[root]]];
    rotationSchedule = buildSchedule[tree, {}, 1];
    maxLevel = Max[Map[#[[3]] &, rotationSchedule]];

    (* Fully unfolded flat net: foldPercent = 1.0 at all levels *)
    foldPercents = Table[1.0, {k, 1, maxLevel}];
    rotatedFaces = foldFaces[faces, rotationSchedule, foldPercents];

    range = 2.6;
    spinAngle = -Pi/2 - Pi/4;
    flipAngle = 0;

    graph = elements3D[rotatedFaces, 1, spinAngle, flipAngle, -1, range, rootFaceCenter];

    outputFileName = FileNameJoin[{outputFolder, "net_" <> IntegerString[netIndex, 10, 2] <> ".png"}];
    If[FileExistsQ[outputFileName], DeleteFile[outputFileName]];
    POVRayRender[graph, Method -> "Triangle", OutputPath -> outputFileName, ImageSize -> imageSize, RenderOptions -> "+A0.001 -J +UA"];
    Print["Saved " <> outputFileName];
];

(* ---- Main ---- *)

Print["Generating dodecahedron faces..."];
faces = generateFaces[p, q];
Print["Generated " <> IntegerString[Length[faces]] <> " faces."];

baseFolder = "AI_assisted_analysis";

(* Read net files *)
orbit60File = FileNameJoin[{baseFolder, "good_nets_orbit60.txt"}];
orbit120File = FileNameJoin[{baseFolder, "good_nets_orbit120.txt"}];

Print["Reading orbit-60 nets..."];
orbit60Nets = ToExpression[Import[orbit60File, "Text"]];
Print["Read " <> IntegerString[Length[orbit60Nets]] <> " orbit-60 nets."];

Print["Reading orbit-120 nets..."];
orbit120Nets = ToExpression[Import[orbit120File, "Text"]];
Print["Read " <> IntegerString[Length[orbit120Nets]] <> " orbit-120 nets."];

(* Create output folders *)
folder60 = FileNameJoin[{baseFolder, "good_net_images_orbit60"}];
folder120 = FileNameJoin[{baseFolder, "good_net_images_orbit120"}];
If[!DirectoryQ[folder60], CreateDirectory[folder60]];
If[!DirectoryQ[folder120], CreateDirectory[folder120]];

(* Render orbit-60 nets *)
testCount = 3; (* Set to Length[orbit60Nets] or Length[orbit120Nets] for full run *)
Print["=== Rendering " <> IntegerString[testCount] <> " orbit-60 nets (test) ==="];
Do[
    Print["Orbit-60 net " <> IntegerString[i] <> " / " <> IntegerString[testCount]];
    renderNet[faces, orbit60Nets[[i]], i, folder60],
    {i, testCount}
];

(* Render orbit-120 nets *)
Print["=== Rendering " <> IntegerString[testCount] <> " orbit-120 nets (test) ==="];
Do[
    Print["Orbit-120 net " <> IntegerString[i] <> " / " <> IntegerString[testCount]];
    renderNet[faces, orbit120Nets[[i]], i, folder120],
    {i, testCount}
];

Print["Done! Generated " <> IntegerString[Length[orbit60Nets] + Length[orbit120Nets]] <> " images total."];
